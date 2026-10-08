import {mkdtemp,writeFile,readFile,rm} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {subprocess,ExportError} from './document.mjs';

function normalized(text) {
  return [...text.normalize('NFKC').replace(/[\s\u200e\u200f\u202a-\u202e\u2066-\u2069]/gu,'')];
}
export function containsText(actual,expected) {
  const counts=new Map();
  for (const c of normalized(actual)) counts.set(c,(counts.get(c)??0)+1);
  for (const c of normalized(expected)) {
    if (!counts.get(c)) return false;
    counts.set(c,counts.get(c)-1);
  }
  return true;
}
export class ChromiumRenderer {
  async browser({timeout=20000}={}) {
    const {chromium}=await import('playwright');
    const allowed=['PATH','HOME','LANG','LD_LIBRARY_PATH','NIX_LD','NIX_LD_LIBRARY_PATH',
      'FONTCONFIG_FILE','FONTCONFIG_PATH','XDG_DATA_DIRS','XDG_CONFIG_DIRS'];
    const env=Object.fromEntries(allowed.filter(key=>process.env[key]).map(key=>[key,process.env[key]]));
    return chromium.launch({headless:true,timeout,env}); // No server credentials in browser env.
  }
  async render(html,{signal,timeout}) {
    if (signal.aborted || timeout<=0) throw new ExportError('STALE_LEASE');
    const browser=await this.browser({timeout:Math.min(20000,timeout)});
    if(signal.aborted){await browser.close();throw new ExportError('STALE_LEASE');}
    const close=()=>{browser.close().catch(()=>{});};
    signal.addEventListener('abort',close,{once:true});
    try {
      const context=await browser.newContext({javaScriptEnabled:false,serviceWorkers:'block'});
      await context.route('**/*',route=>route.abort());
      const page=await context.newPage();
      await page.setContent(html,{waitUntil:'load',timeout});
      await page.evaluate(()=>document.fonts.ready);
      await page.emulateMedia({media:'print'});
      return await page.pdf({preferCSSPageSize:true,printBackground:true,
        displayHeaderFooter:false,timeout});
    } finally {signal.removeEventListener('abort',close);await browser.close();}
  }
  async validate(pdf,html,{signal,timeout=20000}={}) {
    const bounded=AbortSignal.any([...(signal?[signal]:[]),AbortSignal.timeout(Math.max(1,timeout))]);
    if (!Buffer.isBuffer(pdf) || !pdf.subarray(0,5).equals(Buffer.from('%PDF-'))) {
      throw new ExportError('VALIDATION_FAILED');
    }
    const directory=await mkdtemp(join(tmpdir(),'jobix-export-'));
    let browser;
    try {
      const file=join(directory,'document.pdf');
      await writeFile(file,pdf,{mode:0o600});
      const info=(await subprocess('pdfinfo',[file],null,
        {signal:bounded,maxBytes:20000})).toString();
      const match=info.match(/^Pages:\s+(\d+)$/m);
      const pages=Number(match?.[1]);
      if (!pages || pages>20) throw new ExportError('VALIDATION_FAILED');
      await subprocess('pdftotext',['-enc','UTF-8',file,join(directory,'text')],null,
        {signal:bounded});
      const actual=await readFile(join(directory,'text'),'utf8');
      if(bounded.aborted)throw new ExportError('STALE_LEASE');
      browser=await this.browser({timeout:Math.min(20000,timeout)});
      const close=()=>browser.close().catch(()=>{});
      bounded.addEventListener('abort',close,{once:true});
      if(bounded.aborted)throw new ExportError('STALE_LEASE');
      const page=await browser.newPage({javaScriptEnabled:false});
      await page.route('**/*',route=>route.abort());
      await page.setContent(html,{timeout:20000});
      const expected=await page.locator('body').innerText();
      if (!containsText(actual,expected)) throw new ExportError('VALIDATION_FAILED');
      // Source HTML and DOM order are canonical. Bidi print order/geometry remain
      // covered by the existing full offline logical/visual regression suite.
      return pages;
    } finally {if(browser) await browser.close();await rm(directory,{recursive:true,force:true});}
  }
}
