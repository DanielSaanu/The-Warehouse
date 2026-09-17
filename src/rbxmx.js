// Build Roblox XML files straight from the Rojo project, no Rojo needed:
//   TheWarehouse.rbxmx  a model you "Insert from File" into ANY existing place; its Installer script moves
//                       everything into the right services when you press Play.
//   TheWarehouse.rbxlx  a standalone place file (File > Open from File > Play).
import fs from 'node:fs/promises';
import path from 'node:path';
import { DIRS, ROOT, rel } from './paths.js';

const SERVICES = new Set(['Workspace', 'ReplicatedStorage', 'ReplicatedFirst', 'ServerScriptService', 'ServerStorage', 'StarterGui', 'StarterPack', 'StarterPlayer', 'Lighting', 'SoundService', 'Players', 'Teams', 'Chat', 'TextChatService']);

let refCounter = 0;
const ref = () => 'RBX' + (++refCounter).toString(16).padStart(8, '0');
const esc = s => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
const cdata = s => '<![CDATA[' + String(s).replace(/\]\]>/g, ']]]]><![CDATA[>') + ']]>';

/** Read the Rojo project into a neutral tree: { name, className, source?, disabled?, children[] } */
export async function readProjectTree(projectFile = path.join(DIRS.roblox, 'default.project.json')) {
  const project = JSON.parse(await fs.readFile(projectFile, 'utf8'));
  const base = path.dirname(projectFile);
  async function node(name, spec) {
    const n = { name, className: spec.$className || 'Folder', children: [] };
    if (spec.$path) {
      const abs = path.resolve(base, spec.$path);
      const st = await fs.stat(abs);
      if (st.isDirectory()) { n.className = spec.$className || 'Folder'; n.children.push(...await dirChildren(abs)); }
      else Object.assign(n, await fileNode(abs));
    }
    for (const [k, v] of Object.entries(spec)) if (!k.startsWith('$')) n.children.push(await node(k, v));
    return n;
  }
  async function dirChildren(dir) {
    const out = [];
    for (const e of (await fs.readdir(dir, { withFileTypes: true })).sort((a, b) => a.name.localeCompare(b.name))) {
      const abs = path.join(dir, e.name);
      if (e.isDirectory()) out.push({ name: e.name, className: 'Folder', children: await dirChildren(abs) });
      else if (/\.luau?$/.test(e.name)) out.push(await fileNode(abs));
    }
    return out;
  }
  async function fileNode(abs) {
    const file = path.basename(abs).replace(/\.luau?$/, '');
    const source = await fs.readFile(abs, 'utf8');
    if (file.endsWith('.server')) return { name: file.slice(0, -7), className: 'Script', source, children: [] };
    if (file.endsWith('.client')) return { name: file.slice(0, -7), className: 'LocalScript', source, children: [] };
    return { name: file, className: 'ModuleScript', source, children: [] };
  }
  const root = await node(project.name || 'Project', project.tree);
  return root;
}

function itemXml(n, indent = '  ') {
  const props = [`<string name="Name">${esc(n.name)}</string>`];
  if (n.source != null) {
    props.push(`<ProtectedString name="Source">${cdata(n.source)}</ProtectedString>`);
    if (n.className === 'Script' || n.className === 'LocalScript') props.push(`<bool name="Disabled">${n.disabled ? 'true' : 'false'}</bool>`);
  }
  const kids = n.children.map(c => itemXml(c, indent + '  ')).join('');
  return `${indent}<Item class="${n.className}" referent="${ref()}">\n${indent}  <Properties>\n${props.map(p => indent + '    ' + p).join('\n')}\n${indent}  </Properties>\n${kids}${indent}</Item>\n`;
}

const wrap = items => `<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">\n  <Meta name="ExplicitAutoJoints">true</Meta>\n${items}</roblox>\n`;

/** Place file: services at the top level. */
export function placeXml(tree) {
  refCounter = 0;
  const services = tree.children.filter(c => SERVICES.has(c.name)).map(c => ({ ...c, className: c.name }));
  return wrap(services.map(s => itemXml(s)).join(''));
}

/** Model file: Folder <name> { Installer, <ServiceName> folders... }. Server Scripts start Disabled; the installer enables them after moving. */
const NOT_CREATABLE = new Set([...SERVICES, 'StarterPlayerScripts', 'StarterCharacterScripts']);

export function modelXml(tree, installerSource, name = 'TheWarehouse') {
  refCounter = 0;
  // Services and service-like containers become plain Folders; the installer merges them into the real ones.
  const prep = n => ({ ...n, className: NOT_CREATABLE.has(n.className) ? 'Folder' : n.className, disabled: n.className === 'Script' ? true : n.disabled, children: n.children.map(prep) });
  const folders = tree.children.filter(c => SERVICES.has(c.name)).map(prep);
  const root = { name, className: 'Folder', children: [{ name: 'Installer', className: 'Script', source: installerSource, children: [] }, ...folders] };
  return wrap(itemXml(root));
}

export async function writeRobloxFiles({ outDir = path.join(DIRS.exports, 'roblox'), name = 'TheWarehouse', log = () => {} } = {}) {
  const tree = await readProjectTree();
  const installer = await fs.readFile(path.join(DIRS.roblox, 'installer', 'Installer.server.lua'), 'utf8');
  await fs.mkdir(outDir, { recursive: true });
  const model = path.join(outDir, name + '.rbxmx'), place = path.join(outDir, name + '.rbxlx');
  await fs.writeFile(model, modelXml(tree, installer, name));
  await fs.writeFile(place, placeXml(tree));
  log(`wrote ${rel(model)} (insert into any place) and ${rel(place)} (standalone place)`);
  return { model, place };
}
