import express from "express";
import path from "node:path";
import { fileURLToPath } from "node:url";
import dotenv from "dotenv";
import { JsonRpcProvider, Contract } from "ethers";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const localEnv = dotenv.config({ path: path.join(__dirname, ".env") });
if (localEnv.error) {
  dotenv.config({ path: path.join(__dirname, "..", ".env") });
}

const RPC_URL = process.env.SEPOLIA_RPC_URL;
if (!RPC_URL) {
  console.error("Missing SEPOLIA_RPC_URL in environment");
  process.exit(1);
}

const provider = new JsonRpcProvider(RPC_URL);
const ERC721_ABI = ["function tokenURI(uint256 tokenId) view returns (string)"];

const app = express();
app.use(express.json());

const publicDir = path.join(__dirname, "public");
app.use(express.static(publicDir));

app.post("/api/token", async (req, res) => {
  try {
    const { contractAddress, tokenId } = req.body || {};
    if (!contractAddress || !tokenId) {
      return res.status(400).json({ error: "contractAddress and tokenId required" });
    }

    const contract = new Contract(contractAddress, ERC721_ABI, provider);
    const uri = await contract.tokenURI(tokenId);

    const resolved = await resolveTokenURI(uri);
    return res.json({
      tokenUri: uri,
      resolvedMetadata: resolved.metadata,
      rawData: resolved.raw,
      imageUrl: resolved.imageUrl,
      animationUrl: resolved.animationUrl
    });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: err.message || "Unexpected error" });
  }
});

const PORT = process.env.PORT || 4173;
app.listen(PORT, () => {
  console.log(`Token viewer running on http://localhost:${PORT}`);
});

async function resolveTokenURI(uri) {
  if (uri.startsWith("data:")) {
    const [, data] = uri.split(",");
    if (!data) {
      throw new Error("Malformed data URI");
    }
    const buffer = uri.includes(";base64,") ? Buffer.from(data, "base64") : Buffer.from(decodeURIComponent(data));
    return parseMetadataBuffer(buffer.toString("utf8"));
  }

  if (uri.startsWith("ipfs://")) {
    const url = ipfsToHttp(uri);
    const resp = await fetch(url);
    if (!resp.ok) throw new Error(`IPFS fetch failed (${resp.status})`);
    const text = await resp.text();
    return parseMetadataBuffer(text, url);
  }

  const resp = await fetch(uri);
  if (!resp.ok) throw new Error(`HTTP fetch failed (${resp.status})`);
  const text = await resp.text();
  return parseMetadataBuffer(text, uri);
}

function parseMetadataBuffer(text, source) {
  let metadata = null;
  try {
    metadata = JSON.parse(text);
  } catch (err) {
    console.warn("Metadata is not valid JSON", err);
  }

  const imageUrl = normalizeResource(metadata?.image);
  const animationUrl = normalizeResource(metadata?.animation_url);

  return {
    raw: text,
    metadata,
    imageUrl,
    animationUrl,
    source
  };
}

function normalizeResource(value) {
  if (!value) return null;
  if (value.startsWith("ipfs://")) {
    return ipfsToHttp(value);
  }
  return value;
}

function ipfsToHttp(uri) {
  return uri.replace("ipfs://", "https://ipfs.io/ipfs/");
}
