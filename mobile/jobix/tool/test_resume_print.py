"""Negative/self-tests for the offline regression assertions; stdlib only."""
from collections import Counter
import copy
import unittest

from check_resume_print import (
    PROFICIENCIES, authored, check_cohesion, check_dom, check_pdf_content,
    glyphs, pdf_lines, visible_characters, words,
)


def valid_dom():
    personal = {
        "full_name": "Synthetic Name", "email": "test@example.invalid",
        "phone": "+20 100 000 0000", "city": "Test City",
        "country": "Test Country", "portfolio_url": "https://example.invalid/",
    }
    source = {
        "profile_version": 7, "personal": personal, "target_role": "Target Role",
        "summary": "Opening.\n- First bullet\n• Second bullet\n\n1. Numbered prose.",
        "volunteer_experiences": [{
            "role": "Coordinator", "organization": "Group",
            "start_month": "2024-01", "is_current": True,
            "description": "Introduction.\n- Community.\n\nClosing.",
        }],
        "skills": [{"name": "SQL"}, {"name": "Python"}],
    }
    case = {"source": source, "language": "en", "model_version": 2, "template_version": 2}
    dom = {
        "lang": "en", "dir": "ltr", "model": "2", "template": "2",
        "id": "resume_ats_en_v1", "profile": "7",
        "csp": "default-src 'none'; font-src data:",
        "pageRules": [{"size": "a4", "margin": "18mm"}],
        "scripts": 0, "validLists": True, "overflow": [], "lockedEntries": False,
        "fontStatus": [{"family": family, "status": "loaded"} for family in ("Inter", "Plex")],
        "headings": ["Professional Summary", "Volunteer Experience", "Skills"],
        "articles": ["Coordinator"],
        "records": ["Coordinator Group 2024-01 Present Introduction. Community. Closing."],
        "lists": [["First bullet", "Second bullet"], ["Community."]],
        "paragraphs": ["Opening.", "", "1. Numbered prose.", "Introduction.", "", "Closing."],
        "blanks": 2, "header": " ".join(personal.values()) + " Target Role",
        "skills": "SQL · Python",
    }
    return case, dom


def line(text, page, y, height=22):
    sequence = words(text)
    return {"tokens": Counter(sequence), "sequence": sequence,
            "page": page, "y": y, "height": height, "text": text}


def credential_dom(language):
    case, dom = valid_dom()
    ar = language == "ar"
    case["language"] = language
    dom.update(lang=language, dir="rtl" if ar else "ltr",
               id=f"resume_ats_{language}_v1")
    # Independent synthetic oracle, including empty optional records.
    source = case["source"]
    source["volunteer_experiences"] = []
    source["certifications"] = [
        {"name": "شهادة تجريبية" if ar else "Sample Certificate",
         "issuer": "معهد تجريبي" if ar else "Sample Institute",
         "issue_month": "2021-03", "expiry_month": "2029-11",
         "credential_id": "CERT-0042/SQL",
         "url": "https://example.invalid/cert?id=42&lang=en",
         "description": "Credential introduction.\n- Credential outcome."},
        {"name": "شهادة ثانية" if ar else "Second Certificate",
         "issuer": "Second Institute", "issue_month": "2020-02",
         "expiry_month": "", "credential_id": "", "url": "", "description": ""},
    ]
    source["achievements"] = [
        {"title": "إنجاز تجريبي" if ar else "Sample Achievement",
         "issuer": "Sample Committee", "achieved_month": "2022-09",
         "description": "Achievement introduction.\n• Achievement outcome.",
         "url": "https://example.invalid/award?year=2022&kind=sample"},
        {"title": "Second Achievement", "issuer": "Second Committee",
         "achieved_month": "2019-12", "description": "", "url": ""},
    ]
    source["languages"] = [
        {"name": f"لغة {index}" if ar else f"Language {index}", "proficiency": key}
        for index, key in enumerate(PROFICIENCIES)
    ]
    certs, awards = source["certifications"], source["achievements"]
    dom["headings"] = (["الملخص المهني", "الشهادات", "الإنجازات", "المهارات", "اللغات"]
                       if ar else ["Professional Summary", "Certifications",
                                   "Achievements", "Skills", "Languages"])
    dom["articles"] = ([i["name"] for i in certs] + [i["title"] for i in awards] +
                       [i["name"] for i in source["languages"]])
    dom["records"] = [
        f'{certs[0]["name"]} {certs[0]["issuer"]} 2021-03 '
        f'{"تاريخ الانتهاء" if ar else "Expires"}: 2029-11 CERT-0042/SQL '
        f'{certs[0]["url"]} Credential introduction. Credential outcome.',
        f'{certs[1]["name"]} Second Institute 2020-02',
        f'{awards[0]["title"]} Sample Committee 2022-09 '
        f'{awards[0]["url"]} Achievement introduction. Achievement outcome.',
        "Second Achievement Second Committee 2019-12",
        *[f'{i["name"]} {PROFICIENCIES[i["proficiency"]][int(ar)]}'
          for i in source["languages"]],
    ]
    dom["recordLinks"] = [
        [{"text": certs[0]["url"], "href": certs[0]["url"]}], [],
        [{"text": awards[0]["url"], "href": awards[0]["url"]}], [],
        *[[] for _ in source["languages"]],
    ]
    dom["lists"] = [["First bullet", "Second bullet"],
                    ["Credential outcome."], ["Achievement outcome."]]
    dom["paragraphs"] = ["Opening.", "", "1. Numbered prose.",
                         "Credential introduction.", "Achievement introduction."]
    dom["blanks"] = 1
    dom["text"] = "\n".join([dom["header"], *dom["headings"], *dom["records"],
                             *dom["paragraphs"], dom["skills"],
                             "First bullet Second bullet"])
    return case, dom


class ResumeAssertionsTest(unittest.TestCase):
    def test_healthy_dom(self):
        check_dom(*valid_dom())

    def test_credentials_and_all_translated_proficiencies(self):
        for language in ("en", "ar"):
            with self.subTest(language=language):
                case, dom = credential_dom(language)
                check_dom(case, dom)
                check_pdf_content(dom, dom["text"])

    def test_each_credential_field_and_proficiency_cannot_disappear(self):
        for language in ("en", "ar"):
            case, healthy = credential_dom(language)
            fields = [(0, value) for key, value in case["source"]["certifications"][0].items()
                      if key != "description"]
            fields += [(2, value) for key, value in case["source"]["achievements"][0].items()
                       if key != "description"]
            fields += [(4+i, PROFICIENCIES[item["proficiency"]][int(language == "ar")])
                       for i, item in enumerate(case["source"]["languages"])]
            for index, value in fields:
                with self.subTest(language=language, field=value):
                    dom = copy.deepcopy(healthy)
                    dom["records"][index] = dom["records"][index].replace(value, "")
                    with self.assertRaises(AssertionError):
                        check_dom(case, dom)
                    # PDF must fail even when logical DOM remains healthy.
                    with self.assertRaisesRegex(AssertionError, "PDF content mismatch"):
                        check_pdf_content(healthy, healthy["text"].replace(value, ""))

    def test_wrong_translation_is_not_accepted(self):
        for language in ("en", "ar"):
            case, healthy = credential_dom(language)
            for index, labels in enumerate(PROFICIENCIES.values()):
                dom = copy.deepcopy(healthy)
                selected = int(language == "ar")
                dom["records"][4+index] = dom["records"][4+index].replace(
                    labels[selected], labels[1-selected])
                with self.subTest(language=language, index=index), self.assertRaises(AssertionError):
                    check_dom(case, dom)

    def test_optional_fields_links_and_section_order(self):
        case, healthy = credential_dom("en")
        for regression in ("expiry", "link", "href", "sections", "records", "moved"):
            dom = copy.deepcopy(healthy)
            if regression == "expiry":
                dom["records"][1] += " Expires: 2029-11"
            elif regression == "link":
                dom["recordLinks"][1] = dom["recordLinks"][0]
            elif regression == "href":
                dom["recordLinks"][0][0]["href"] = "https://example.invalid/wrong"
            elif regression == "sections":
                dom["headings"][1:3] = reversed(dom["headings"][1:3])
            elif regression == "records":
                dom["records"].append("Unexpected duplicate")
            else:
                dom["records"][0], dom["records"][2] = dom["records"][2], dom["records"][0]
            with self.subTest(regression=regression), self.assertRaises(AssertionError):
                check_dom(case, dom)

    def test_dom_regressions_fail(self):
        case, healthy = valid_dom()
        changes = [
            ("skills", "SQL"),
            ("lists", [["First bullet"], ["Community."]]),
            ("paragraphs", ["Opening.", "", "Introduction.", "", "Closing."]),
            ("blanks", 0),
            ("records", ["Coordinator 2024-01 Introduction. Community. Closing."]),
            ("records", ["Coordinator Group 2024-01 Present Closing. Community. Introduction."]),
            ("paragraphs", list(reversed(healthy["paragraphs"]))),
            ("headings", ["Professional Summary", "Work Experience", "Skills"]),
            ("model", "1"), ("template", "1"), ("validLists", False),
            ("overflow", ["A"]), ("lockedEntries", True), ("scripts", 1),
            ("fontStatus", []), ("pageRules", [{"size": "letter", "margin": "12mm"}]),
        ]
        for key, value in changes:
            with self.subTest(regression=key), self.assertRaises(AssertionError):
                dom = copy.deepcopy(healthy)
                dom[key] = value
                check_dom(case, dom)

    def test_bidi_shaping_and_reordering_are_not_content_loss(self):
        self.assertEqual(glyphs("العربية SQL 0_11"), glyphs("\u200fﺍﻟﻌﺮﺑﻴﺔ SQL 11_0"))
        self.assertNotEqual(glyphs("العربية SQL 0_11"), glyphs("العربية SQL 11"))
        self.assertNotEqual(glyphs("Repeated Repeated"), glyphs("Repeated"))

    def test_only_unambiguous_bullets_become_lists(self):
        lists, prose = authored("- Bullet\n• Next\n\n1. Numbered\n-no-space\n•no-space")
        self.assertEqual(lists, [["Bullet", "Next"]])
        self.assertEqual(prose, ["", "1. Numbered", "-no-space", "•no-space"])

    def test_punctuation_loss_is_content_loss(self):
        self.assertNotEqual(visible_characters("test@example.invalid"),
                            visible_characters("testexample.invalid"))
        self.assertEqual(visible_characters("\u2066SQL / العربية\u2069"),
                         visible_characters("SQL / العربية"))

    def test_heading_font_disambiguates_metadata_in_both_directions(self):
        anchors = [
            {"heading": "Summary", "next": "Opening", "gap": 20, "tag": "H2"},
            {"heading": "المشروعات", "next": "مشروع تجريبي", "gap": 20, "tag": "H2"},
        ]
        lines = [
            line("Summary", 0, 60), line("Opening", 0, 80, 18),
            line("تنسيق المشروعات", 0, 120, 18),
            line("المشروعات", 1, 60), line("تجريبي مشروع", 1, 80, 19),
        ]
        check_cohesion(anchors, lines)
        lines[-1]["page"] = 2
        with self.assertRaisesRegex(AssertionError, "orphaned"):
            check_cohesion(anchors, lines)

    def test_orphan_and_artificial_gap_fail(self):
        anchors = [{"heading": "Work Experience", "next": "Team Coordinator",
                    "gap": 20, "tag": "H2"}]
        for page, y in [(1, 70), (0, 190)]:
            with self.subTest(page=page), self.assertRaisesRegex(AssertionError, "orphaned"):
                check_cohesion(anchors, [line("Work Experience", 0, 60),
                                        line("Team Coordinator", page, y)])

    def test_paper_and_clipping_guards(self):
        def xml(width=595.28, x=60, y=60):
            return (f'<doc><page width="{width}" height="841.89"><flow><block>'
                    f'<line yMin="{y}" yMax="{y+20}"><word xMin="{x}" xMax="{x+30}" '
                    f'yMin="{y}" yMax="{y+20}">Synthetic</word></line></block></flow></page></doc>')
        self.assertEqual(len(pdf_lines(xml())[0]), 1)
        for args in [{"width": 612}, {"x": 10}, {"y": 820}]:
            with self.subTest(args=args), self.assertRaises(AssertionError):
                pdf_lines(xml(**args))


if __name__ == "__main__":
    unittest.main()
