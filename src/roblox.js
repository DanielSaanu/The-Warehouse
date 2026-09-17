// Roblox Open Cloud: upload an image as a Decal asset, poll the operation, return the asset id.
// Docs: https://create.roblox.com/docs/cloud/reference/Asset
import fs from 'node:fs/promises';
import { loadEnv } from './env.js';

const API = 'https://apis.roblox.com/assets/v1';

export function robloxConfig() {
  loadEnv();
  const key = process.env.ROBLOX_API_KEY;
  const userId = process.env.ROBLOX_CREATOR_USER_ID;
  const groupId = process.env.ROBLOX_CREATOR_GROUP_ID;
  if (!key) throw new Error('ROBLOX_API_KEY missing. See docs/ROBLOX_SETUP.md');
  if (!userId && !groupId) throw new Error('Set ROBLOX_CREATOR_USER_ID or ROBLOX_CREATOR_GROUP_ID in .env');
  return { key, creator: groupId ? { groupId: String(groupId) } : { userId: String(userId) } };
}

/** Upload a PNG buffer. Returns { assetId, operationId }. */
export async function uploadImage(buf, { name, description = 'Uploaded by The Warehouse', assetType = 'Decal' } = {}) {
  const { key, creator } = robloxConfig();
  const form = new FormData();
  form.append('request', JSON.stringify({ assetType, displayName: name.slice(0, 50), description: description.slice(0, 1000), creationContext: { creator } }));
  form.append('fileContent', new Blob([buf], { type: 'image/png' }), name.replace(/[^\w.-]/g, '_') + '.png');
  const res = await fetch(`${API}/assets`, { method: 'POST', headers: { 'x-api-key': key }, body: form });
  const text = await res.text();
  if (!res.ok) throw new Error(`Roblox upload failed ${res.status}: ${text}`);
  const op = JSON.parse(text);
  const operationId = op.operationId || (op.path || '').split('/').pop();
  const assetId = await pollOperation(operationId, key);
  return { assetId, operationId };
}

async function pollOperation(operationId, key, { tries = 20, delayMs = 1500 } = {}) {
  for (let i = 0; i < tries; i++) {
    const res = await fetch(`${API}/operations/${operationId}`, { headers: { 'x-api-key': key } });
    const json = await res.json();
    if (json.done) {
      if (json.error) throw new Error(`Roblox operation error: ${JSON.stringify(json.error)}`);
      const id = json.response?.assetId;
      if (!id) throw new Error(`operation finished without assetId: ${JSON.stringify(json)}`);
      return String(id);
    }
    await new Promise(r => setTimeout(r, delayMs));
  }
  throw new Error(`operation ${operationId} did not finish; check Creator Hub > Development Items > Decals`);
}

/**
 * Decal ids work directly in ImageLabel.Image (Roblox resolves them). If you ever need the underlying
 * image id (some APIs want it), this tries the public asset delivery XML. Falls back to the decal id.
 */
export async function resolveImageId(decalId) {
  try {
    const res = await fetch(`https://assetdelivery.roblox.com/v1/asset/?id=${decalId}`);
    if (!res.ok) return decalId;
    const xml = await res.text();
    const m = xml.match(/<url>[^<]*?id=(\d+)/i) || xml.match(/rbxassetid:\/\/(\d+)/);
    return m ? m[1] : decalId;
  } catch { return decalId; }
}

export async function uploadFile(file, opts) { return uploadImage(await fs.readFile(file), opts); }
