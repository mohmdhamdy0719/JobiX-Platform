import {createHash} from 'node:crypto';
import {spawn} from 'node:child_process';
import {readFile} from 'node:fs/promises';
import {resolve} from 'node:path';

export const bundle = 'jobix-resume-export-1';
export const sha256 = value => createHash('sha256').update(value).digest('hex');
export function fontChecksums(html) {
  return [...html.matchAll(/data:font\/ttf;base64,([A-Za-z0-9+/=]+)/g)]
    .map(match=>sha256(Buffer.from(match[1],'base64')));
}
export class ExportError extends Error {
  constructor(code, retryAfterSeconds = null) {
    super(code); this.code = code;
    this.retryAfterSeconds = Number.isSafeInteger(retryAfterSeconds) && retryAfterSeconds > 0
      ? retryAfterSeconds : null;
  }
}
export const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
export function requireUuid(value) {
  if (typeof value !== 'string' || !uuid.test(value)) throw new ExportError('VALIDATION_FAILED');
  return value;
}
export function logicalHash(command) {
  function sorted(value) {
    if (Array.isArray(value)) return value.map(sorted);
    if (value && typeof value === 'object') return Object.fromEntries(
      Object.keys(value).sort().map(key => [key, sorted(value[key])]));
    return value;
  }
  return sha256(JSON.stringify(sorted({
    expected_profile_version: command.expected_profile_version,
    payload: command.payload,
  })));
}
export function subprocess(program, args, input, {signal, maxBytes = 8000000} = {}) {
  return new Promise((yes, no) => {
    const child = spawn(program, args, {stdio:['pipe','pipe','pipe'], signal,
      env: {PATH:process.env.PATH, HOME:process.env.HOME, LANG:'C.UTF-8'}});
    const chunks = []; let bytes = 0;
    child.stdout.on('data', chunk => {
      bytes += chunk.length;
      if (bytes > maxBytes) { child.kill(); no(new ExportError('VALIDATION_FAILED')); }
      else chunks.push(chunk);
    });
    // Never propagate raw stderr, which may contain private content.
    child.stderr.resume();
    child.on('error', () => no(new ExportError('SERVICE_UNAVAILABLE')));
    child.on('close', code => code === 0 ? yes(Buffer.concat(chunks)) :
      no(new ExportError('VALIDATION_FAILED')));
    child.stdin.on('error', () => {});
    child.stdin.end(input);
  });
}
export class Canonicalizer {
  constructor({root = resolve(import.meta.dirname, '../..'), dart = 'dart',execute=subprocess,
    executable=process.env.JOBIX_CANONICAL_EXECUTABLE} = {}) {
    Object.assign(this,{root,dart,execute,executable});
  }
  async prepare(input) {
    const signal=AbortSignal.timeout(30000);
    const program=this.executable??this.dart;
    const args=this.executable?[this.root]:[resolve(this.root,'tool/prepare_resume_document.dart'),this.root];
    const facts=JSON.parse(await this.execute(program,
      [...args,'source'],
      JSON.stringify(input.source),{signal}));
    if(facts.bundle!==bundle || typeof facts.source_text!=='string' ||
      Buffer.byteLength(facts.source_text.normalize('NFC'))>200000)throw new ExportError('VALIDATION_FAILED');
    const output = await this.execute(program,args,
      JSON.stringify(input.source), {signal});
    let document;
    try { document = JSON.parse(output); } catch { throw new ExportError('VALIDATION_FAILED'); }
    if (document.bundle !== bundle || typeof document.html !== 'string' ||
        Buffer.byteLength(document.source_text.normalize('NFC')) > 200000) {
      throw new ExportError('VALIDATION_FAILED');
    }
    const fonts=fontChecksums(document.html);
    if(fonts.length!==2)throw new ExportError('VALIDATION_FAILED');
    const config=input.source.configuration;
    const layoutV1=config.render_config_version==='export-layout-v1';
    if(layoutV1 && (config.template_version!==3 ||
      !document.html.includes('<meta name="jobix-layout-version" content="1">'))) {
      throw new ExportError('APP_UPDATE_REQUIRED');
    }
    const licenses=await Promise.all(['OFL.txt','OFL-IBMPlexSansArabic.txt']
      .map(name=>readFile(resolve(this.root,'assets/fonts',name),'utf8')));
    return {
      html:document.html, document_sha256:sha256(document.html),
      source_sha256:input.source_sha256, bundle, issues:document.issues,
      profile_version:input.source.profile.profile_version,
      configuration_version:input.source.configuration.version,
      language:input.source.configuration.language,
      configuration:input.source.configuration,
      // The hash covers exact HTML including immutable embedded font bytes.
      font_sha256:fonts,
      asset_manifest:{bundle,font_checksums:fonts,model_version:2,template_version:layoutV1?3:2,
        render_config_version:layoutV1?'export-layout-v1':'export-v1',
        licenses:licenses.map((text,index)=>({font:index===0?'Inter':'IBM Plex Sans Arabic',
          sha256:sha256(text),text}))},
    };
  }
}
