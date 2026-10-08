#!/usr/bin/env python3
"""Offline canonical Resume regression suite. Requires existing Dart/Chromium/Poppler.

Run from any directory: python3 mobile/jobix/tool/check_resume_print.py
All artifacts are synthetic and temporary; --keep retains their /tmp directory.
No HTTP server, package restore, credentials, application or live data is used.
"""
import argparse
import base64
from collections import Counter
import json
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unicodedata
import xml.etree.ElementTree as ET

from resume_print_cdp import Chromium, tool_environment

ROOT = Path(__file__).resolve().parents[1]
SECTIONS = [
    ("experiences", "Work Experience", "الخبرة المهنية", "job_title"),
    ("volunteer_experiences", "Volunteer Experience", "الخبرات التطوعية", "role"),
    ("education", "Education", "التعليم", "degree"),
    ("certifications", "Certifications", "الشهادات", "name"),
    ("achievements", "Achievements", "الإنجازات", "title"),
    ("projects", "Projects", "المشروعات", "name"),
    ("skills", "Skills", "المهارات", "name"),
    ("languages", "Languages", "اللغات", "name"),
]
DOM = r"""(() => {
  const text = e => e?.textContent.trim() || '';
  const meta = name => document.querySelector(`meta[name="${name}"]`)?.content;
  const anchors = [];
  const add = (heading, next) => {
    if (next && text(next)) anchors.push({
      heading:text(heading), next:text(next),
      tag:heading.tagName,
      gap:(next.getBoundingClientRect().top-heading.getBoundingClientRect().top)*.75
    });
  };
  for (const h of document.querySelectorAll('section > h2')) {
    const next=h.nextElementSibling;
    add(h,next?.matches('article') ? next.querySelector('h3')
      : next?.matches('ul') ? next.querySelector('li') : next);
  }
  for (const a of document.querySelectorAll('article')) {
    const h=a.querySelector('h3');
    add(h,a.querySelector('.meta'));
    const first=[...a.children].find(e=>!e.matches('header,.meta'));
    add(h,first?.matches('ul') ? first.querySelector('li') : first);
  }
  const elements=[...document.querySelectorAll('h1,h2,h3,p,li,a,.contact,header')];
  return {
    lang:document.documentElement.lang, dir:document.documentElement.dir,
    model:meta('jobix-render-version'), template:meta('jobix-template-revision'),
    id:meta('jobix-template'), profile:meta('jobix-profile-version'),
    csp:document.querySelector('meta[http-equiv="Content-Security-Policy"]')?.content,
    pageRules:[...document.styleSheets].flatMap(s=>[...s.cssRules])
      .filter(r=>r.type===CSSRule.PAGE_RULE)
      .map(r=>({size:r.style.getPropertyValue('size'),margin:r.style.margin})),
    text:document.body.innerText,
    header:text(document.querySelector('.personal-header')),
    headings:[...document.querySelectorAll('section > h2')].map(text),
    articles:[...document.querySelectorAll('article h3')].map(text),
    records:[...document.querySelectorAll('article')].map(e=>e.innerText),
    paragraphs:[...document.querySelectorAll('p')].map(text),
    lists:[...document.querySelectorAll('ul')].map(e=>[...e.children].map(text)),
    validLists:[...document.querySelectorAll('ul')].every(e=>
      [...e.children].every(c=>c.tagName==='LI')) &&
      [...document.querySelectorAll('li')].every(e=>e.parentElement.tagName==='UL'),
    blanks:document.querySelectorAll('p.blank > br').length,
    scripts:document.querySelectorAll('script').length,
    skills:text(document.querySelector('.skills')),
    overflow:elements.filter(e=>e.scrollWidth>e.clientWidth+1).map(e=>e.tagName),
    lockedEntries:[...document.querySelectorAll('article')].some(e=>
      getComputedStyle(e).breakInside==='avoid'),
    fontStatus:[...document.fonts].map(f=>({family:f.family,status:f.status})),
    anchors
  };
})()"""


def require(condition, message):
    if not condition:
        raise AssertionError(message)


def normalized(text):
    # Poppler may output presentation ligatures and visual RTL ordering.
    return unicodedata.normalize("NFKC", text)


def glyphs(text):
    # Compare complete alphanumeric multiplicities, not a lossy set or a single
    # end sentinel. DOM checks independently preserve logical text/order and
    # punctuation. This tolerates bidi controls, shaping and line wrapping only.
    return Counter(c for c in normalized(text) if c.isalnum())


def visible_characters(text):
    return Counter(c for c in normalized(text)
                   if not c.isspace() and unicodedata.category(c) != "Cf")


def word_key(text):
    return "".join(sorted(c for c in normalized(text) if c.isalnum()))


def words(text):
    return [key for word in text.split() if (key := word_key(word))]


def authored(description):
    lists, prose, group = [], [], []
    for line in description.split("\n"):
        match = re.match(r"^\s*[-•]\s+(.+)$", line)
        if match:
            group.append(match[1].strip())
        else:
            if group:
                lists.append(group)
                group = []
            prose.append(line.strip())
    if group:
        lists.append(group)
    return lists, prose


def check_dom(case, dom):
    source, ar = case["source"], case["language"] == "ar"
    require(dom["lang"] == case["language"] and dom["dir"] == ("rtl" if ar else "ltr"),
            "language/direction mismatch")
    require(dom["model"] == str(case["model_version"]) and
            dom["template"] == str(case["template_version"]) and
            dom["id"] == f"resume_ats_{case['language']}_v1" and
            dom["profile"] == str(source["profile_version"]), "revision/identity mismatch")
    require("default-src 'none'" in dom["csp"] and "font-src data:" in dom["csp"],
            "offline CSP/embedded font contract missing")
    require(dom["pageRules"] == [{"size": "a4", "margin": "18mm"}],
            "canonical A4/18mm stylesheet contract missing")
    require(dom["scripts"] == 0, "unexpected authored executable markup")
    require(dom["validLists"], "invalid UL/LI structure")
    require(not dom["overflow"], f"horizontal overflow: {dom['overflow']}")
    require(not dom["lockedEntries"], "whole-entry pagination lock")
    require({f["family"] for f in dom["fontStatus"] if f["status"] == "loaded"} >=
            {"Inter", "Plex"}, "packaged fonts not loaded")
    expected_headings = ["الملخص المهني" if ar else "Professional Summary"]
    titles, descriptions = [], [source["summary"]]
    record_index = 0
    for key, en, arabic, title in SECTIONS:
        items = source.get(key, [])
        if not items:
            continue
        expected_headings.append(arabic if ar else en)
        if key == "skills":
            require(dom["skills"] == " · ".join(i["name"] for i in items),
                    "compact selectable skills lost/reordered")
        else:
            titles.extend(i[title] for i in items)
            descriptions.extend(i.get("description", "") for i in items
                                if i.get("description", ""))
            for item in items:
                require(record_index < len(dom["records"]), "record body missing")
                record_text = dom["records"][record_index]
                for field in ("company", "organization", "institution", "field_of_study",
                              "issuer", "role", "location", "credential_id",
                              "start_month", "end_month", "issue_month", "expiry_month",
                              "achieved_month", "project_month", "url"):
                    if item.get(field) and not (field == "end_month" and item.get("is_current")):
                        require(item[field] in record_text,
                                f"record lost {field}: {item[field]}")
                cursor = 0
                for line in item.get("description", "").split("\n"):
                    match = re.match(r"^\s*[-•]\s+(.+)$", line)
                    text = (match[1] if match else line).strip()
                    if text:
                        position = record_text.find(text, cursor)
                        require(position >= 0, "record description lost/reordered/moved")
                        cursor = position + len(text)
                record_index += 1
    require(dom["headings"] == expected_headings, "section order/paid-unpaid separation lost")
    require(dom["articles"] == titles, "record titles lost/reordered")
    expected_lists, prose = [], []
    for description in descriptions:
        groups, paragraphs = authored(description)
        expected_lists.extend(groups)
        prose.extend(paragraphs)
    require(dom["lists"] == expected_lists, "authored bullet text/grouping lost")
    actual_paragraphs = Counter(dom["paragraphs"])
    require(actual_paragraphs >= Counter(prose), "plain/numbered prose lost or became bullets")
    paragraph_iter = iter(dom["paragraphs"])
    require(all(any(actual == expected for actual in paragraph_iter) for expected in prose),
            "authored paragraphs reordered")
    require(dom["blanks"] == prose.count(""), "authored blank lines lost")
    for key in ("full_name", "email", "phone", "city", "country", "portfolio_url"):
        require(source["personal"][key] in dom["header"], f"personal header lost {key}")
    require(source["target_role"] in dom["header"], "target role lost")


def pdf_lines(xml):
    root = ET.fromstring(xml)
    pages, lines = [], []
    for index, page in enumerate(root.findall(".//{*}page")):
        width, height = float(page.attrib["width"]), float(page.attrib["height"])
        require(abs(width-595.276) < 1 and abs(height-841.89) < 1, "not A4 geometry")
        page_words = page.findall(".//{*}word")
        for word in page_words:
            x0, x1 = float(word.attrib["xMin"]), float(word.attrib["xMax"])
            y0, y1 = float(word.attrib["yMin"]), float(word.attrib["yMax"])
            margin = 18*72/25.4
            # Poppler reports font ascent/descent boxes, not painted ink.
            # Inter's 24pt heading box extends ~3pt above its CSS line box.
            require(x0 >= margin-1.5 and x1 <= width-margin+1.5 and
                    y0 >= margin-5 and y1 <= height-margin+5,
                    f"text outside 18mm printable margins on page {index+1}: {word.text}")
        pages.append(" ".join(w.text or "" for w in page_words))
        for line in page.findall(".//{*}line"):
            line_words = line.findall("{*}word")
            lines.append({
                "page": index, "y": float(line.attrib["yMin"]),
                "height": float(line.attrib["yMax"])-float(line.attrib["yMin"]),
                "tokens": Counter(word_key(w.text or "") for w in line_words),
                "sequence": [key for w in line_words if (key := word_key(w.text or ""))],
                "text": " ".join(w.text or "" for w in line_words),
            })
    return pages, lines


def check_cohesion(anchors, lines):
    heading_heights = {}
    for anchor in anchors:
        heading = words(anchor["heading"])
        def contains(sequence):
            return any(sequence[i:i+len(heading)] in (heading, heading[::-1])
                       for i in range(len(sequence)-len(heading)+1))
        found = [line for line in lines if contains(line["sequence"])]
        # A one-word Arabic section label can also occur in field-of-study
        # metadata. Use the tagged heading's observed font box, not text alone.
        reference = heading_heights.get(anchor["tag"])
        if reference is not None:
            found = [line for line in found if abs(line["height"]-reference) < .3]
        require(len(found) == 1, f"heading not uniquely extractable: {anchor['heading']}")
        start = found[0]
        heading_heights.setdefault(anchor["tag"], start["height"])
        # The first three non-punctuation words fit these fixture lines. Taking
        # a prefix avoids incorrectly requiring an entire wrapped paragraph.
        following = Counter(words(anchor["next"])[:3])
        require(any(line["page"] == start["page"] and
                    -1.5 <= line["y"]-start["y"] <= anchor["gap"]+12 and
                    line["tokens"] >= following for line in lines),
                f"orphaned heading/metadata: {anchor['heading']} -> {anchor['next'][:70]}")


def check_pdf(case, dom, text, xml, fonts):
    actual, expected = visible_characters(text), visible_characters(dom["text"])
    missing, extra = expected-actual, actual-expected
    # Some Poppler/Chromium versions expose CSS disc markers as Unicode;
    # others paint them as vectors. Authored punctuation must still survive.
    marker_count = sum(map(len, dom["lists"]))
    require(not missing and (not extra or extra == Counter({"•": marker_count})),
            f"PDF content mismatch; missing={dict(expected-actual)}, extra={dict(actual-expected)}")
    pages, lines = pdf_lines(xml)
    require(len(pages) == 1 if case["case"] == "short" else len(pages) > 1,
            "short fixture must fit; expanded fixture must exercise pagination")
    check_cohesion(dom["anchors"], lines)
    records = case["source"]["experiences"]
    expected_markers = re.findall(r"JXR[A-Z]L[A-Z]", "\n".join(r["description"] for r in records))
    actual_markers = re.findall(r"JXR[A-Z]L[A-Z]", text)
    require(Counter(actual_markers) == Counter(expected_markers), "authored line marker lost/duplicated")
    spans = sum(len({
        line["page"] for line in lines
        if re.search(f"JXR{chr(65+i)}L[A-Z]", line["text"])
    }) > 1 for i in range(len(records)))
    require(case["case"] != "long" or spans > 0, "long fixture did not exercise split entries")
    rows = fonts.splitlines()[2:]
    require(rows, "PDF has no embedded text fonts")
    for row in rows:
        match = re.search(r"(yes|no)\s+(yes|no)\s+(yes|no)\s+\d+\s+\d+\s*$", row)
        require(match and match[1] == "yes" and match[3] == "yes",
                "PDF font is not embedded with Unicode extraction")
        require("Inter" in row or "IBMPlexSansArabic" in row, "unexpected fallback font")
    require(("Inter" if case["language"] == "en" else "IBMPlexSansArabic") in fonts,
            "wrong primary packaged font")
    return {"file": case["file"], "pages": len(pages), "split_entries": spans,
            "glyphs": sum(expected.values()), "cohesion_checks": len(dom["anchors"])}


def command(args, **kwargs):
    return subprocess.check_output(args, timeout=60, env=tool_environment(), **kwargs)


def run(directory, binaries):
    # Direct VM execution avoids Dart CLI telemetry/package startup. The
    # generator imports only the canonical app's pure-Dart sources relatively.
    command([binaries["dart"], "--disable-dart-dev",
             "tool/render_resume_fixtures.dart", str(directory),
             "--regression"], cwd=ROOT)
    cases = json.loads((directory / "manifest.json").read_text())
    browser = Chromium(binaries["chromium"], directory)
    reports = []
    try:
        for case in cases:
            target = browser.call("Target.createTarget", {"url": "about:blank"})["targetId"]
            session = browser.call("Target.attachToTarget", {
                "targetId": target, "flatten": True,
            })["sessionId"]
            browser.call("Page.enable", session=session)
            browser.call("Network.enable", session=session)
            browser.call("Network.setBlockedURLs", {"urls": ["http://*", "https://*"]}, session)
            browser.call("Emulation.setDeviceMetricsOverride", {
                "width": 658, "height": 1123, "deviceScaleFactor": 1, "mobile": False,
            }, session)
            browser.call("Emulation.setEmulatedMedia", {"media": "print"}, session)
            browser.call("Page.navigate", {"url": (directory/case["file"]).as_uri()}, session)
            browser.evaluate("""new Promise((resolve,reject) => {
              const deadline=Date.now()+15000;
              const tick=async()=>{
                if(document.readyState==='complete' && document.querySelector('h1')){
                  await Promise.all([document.fonts.load('11pt Inter'),
                    document.fonts.load('11pt Plex','العربية')]);
                  await document.fonts.ready; resolve(true);
                } else if(Date.now()>deadline) reject(new Error('fixture load timeout'));
                else setTimeout(tick,50);
              }; tick();
            })""", session)
            dom = browser.evaluate(DOM, session)
            check_dom(case, dom)
            stem = directory / Path(case["file"]).stem
            (stem.with_suffix(".dom.json")).write_text(json.dumps(dom, ensure_ascii=False))
            pdf = browser.call("Page.printToPDF", {
                "preferCSSPageSize": True, "printBackground": True,
                "displayHeaderFooter": False, "scale": 1,
            }, session)
            stem.with_suffix(".pdf").write_bytes(base64.b64decode(pdf["data"]))
            text = command([binaries["pdftotext"], "-layout", str(stem.with_suffix(".pdf")),
                            "-"]).decode()
            xml = command([binaries["pdftotext"], "-bbox-layout",
                           str(stem.with_suffix(".pdf")), "-"]).decode()
            fonts = command([binaries["pdffonts"], str(stem.with_suffix(".pdf"))]).decode()
            report = check_pdf(case, dom, text, xml, fonts)
            stem.with_suffix(".txt").write_text(text)
            if case["case"] == "boundary-10":
                image = browser.call("Page.captureScreenshot", {
                    "format": "png", "clip": {"x": 0, "y": 0, "width": 658,
                                             "height": 1000, "scale": 1},
                }, session)
                stem.with_suffix(".png").write_bytes(base64.b64decode(image["data"]))
            reports.append(report)
            print(f"PASS {case['file']}: {report['pages']} A4 pages, "
                  f"{report['cohesion_checks']} cohesion checks, complete text/skills/fonts")
            browser.call("Target.closeTarget", {"targetId": target})
    finally:
        browser.close()
    (directory/"report.json").write_text(json.dumps(reports, indent=2))
    print(f"PASS: {len(reports)} canonical fixtures; no fixed long-document page counts.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--keep", action="store_true", help="retain synthetic evidence in /tmp")
    args = parser.parse_args()
    binaries = {name: shutil.which(name) for name in ("dart", "chromium", "pdftotext", "pdffonts")}
    missing = [name for name, path in binaries.items() if not path]
    if missing:
        raise RuntimeError("Missing existing tools (no auto-install): " + ", ".join(missing))
    directory = Path(tempfile.mkdtemp(prefix="jobix-resume-regression-"))
    try:
        run(directory, binaries)
    except Exception:
        print(f"FAIL: synthetic diagnostic evidence retained at {directory}")
        raise
    else:
        if args.keep:
            print(f"Synthetic evidence: {directory}")
        else:
            shutil.rmtree(directory)


if __name__ == "__main__":
    main()
