const { ethers } = require("hardhat");
const fs = require("fs");
const path = require("path");

async function main() {
  const collectionPhrase = "half the battle's just gettin outta bed";
  const startYear = 2026;
  const numTokens = 1000;
  
  console.log("=== GENERATING 1000-TOKEN BLOCKCHAIN SIMULATION ===");
  console.log("Collection:", collectionPhrase);
  console.log("Tokens:", numTokens);
  
  // Deploy SongAlgorithm
  const SongAlgorithm = await ethers.getContractFactory("SongAlgorithm");
  const algo = await SongAlgorithm.deploy();
  await algo.waitForDeployment();
  console.log("SongAlgorithm deployed to:", await algo.getAddress());
  
  // Generate collection salt
  const collectionSalt = ethers.keccak256(ethers.toUtf8Bytes(collectionPhrase));
  console.log("Collection salt:", collectionSalt);
  
  // Create output directory with timestamp
  const timestamp = new Date().toISOString().replace(/[:.]/g, '-').slice(0, -5);
  const baseDir = `OUTPUTS/blockchain-sim-${timestamp}`;
  const beatsDir = `${baseDir}/individual-beats`;
  fs.mkdirSync(beatsDir, { recursive: true });
  console.log("Output:", baseDir);
  
  // Word bank (must match Solidity)
  const wordBank = [
    "harmony", "melody", "rhythm", "crescendo", "allegro", "andante", "forte", "piano",
    "symphony", "sonata", "chord", "scale", "tempo", "timbre", "resonance", "cadence",
    "vibrato", "staccato", "legato", "diminuendo", "accelerando", "ritardando", "sforzando",
    "passage", "phrase", "movement", "composition", "arrangement", "improvisation", "modulation",
    "transpose", "chromatic", "diatonic", "enharmonic", "counterpoint", "polyphony", "monophony",
    "octave", "interval", "consonance", "dissonance", "resolution", "suspension", "ornament"
  ];
  
  // Generate tokens
  const tokens = [];
  let previousNotesHash = ethers.ZeroHash;
  
  let combinedAbc = "";
  let combinedMidiEvents = [];
  let csvRows = ["token_id,reveal_index,reveal_year,seven_words,lead_pitch,lead_duration,bass_pitch,bass_duration,final_seed_preview,collection_phrase"];
  
  for (let i = 0; i < numTokens; i++) {
    const tokenId = 1000 + i * 7;
    const revealIndex = i;
    const revealYear = startYear + i;
    
    // Generate seven words
    const sevenWordsHash = ethers.keccak256(ethers.toUtf8Bytes(`seven_words_${tokenId}`));
    const sevenWords = [];
    for (let j = 0; j < 7; j++) {
      const wordIndex = parseInt(sevenWordsHash.slice(2 + j * 2, 4 + j * 2), 16) % wordBank.length;
      sevenWords.push(wordBank[wordIndex]);
    }
    
    // Global state hash (placeholder)
    const globalStateHash = ethers.keccak256(ethers.toUtf8Bytes(`global_${i}`));
    
    // Final seed
    const finalSeed = ethers.keccak256(
      ethers.concat([
        collectionSalt,
        ethers.zeroPadValue(ethers.toBeHex(tokenId), 32),
        sevenWordsHash,
        previousNotesHash,
        globalStateHash
      ])
    );
    
    const seedInt = parseInt(finalSeed.slice(2, 10), 16);
    
    // Call contract to generate beat
    const [lead, bass] = await algo.generateBeat(i, seedInt);
    
    // Update previous notes hash
    previousNotesHash = ethers.keccak256(
      ethers.concat([
        previousNotesHash,
        ethers.zeroPadValue(ethers.toBeHex(lead.pitch), 1),
        ethers.zeroPadValue(ethers.toBeHex(bass.pitch), 1)
      ])
    );
    
    // Format ABC beat
    const abcBeat = await algo.generateAbcBeat(i, seedInt);
    combinedAbc += `% Token ${tokenId} - Year ${revealYear} - Beat ${i}\n${abcBeat}\n`;
    
    // Format MIDI event
    combinedMidiEvents.push({
      beat: i,
      lead: { pitch: Number(lead.pitch), duration: Number(lead.duration) },
      bass: { pitch: Number(bass.pitch), duration: Number(bass.duration) }
    });
    
    // CSV row
    csvRows.push(`${tokenId},${revealIndex},${revealYear},"${sevenWords.join(' | ')}",${lead.pitch},${lead.duration},${bass.pitch},${bass.duration},${finalSeed.slice(0, 18)},${collectionPhrase}`);
    
    // Progress
    if ((i + 1) % 100 === 0) console.log(`  Generated ${i + 1}/${numTokens} tokens...`);
  }
  
  // Save combined ABC
  const abcHeader = `X:1\nT:Millennium Song - Blockchain Simulation\nC:Collection: "${collectionPhrase}"\nM:4/4\nL:1/8\nK:Eb\nV:1 clef=treble name="Lead"\nV:2 clef=bass name="Bass"\n`;
  fs.writeFileSync(`${baseDir}/combined-sequence.abc`, abcHeader + combinedAbc);
  
  // Save combined MIDI JSON
  fs.writeFileSync(`${baseDir}/combined-midi-info.json`, JSON.stringify({
    metadata: { collection: collectionPhrase, key: "Eb major", numTokens },
    events: combinedMidiEvents
  }, null, 2));
  
  // Save CSV
  fs.writeFileSync(`${baseDir}/token_metadata.csv`, csvRows.join("\n"));
  
  // Save README
  fs.writeFileSync(`${baseDir}/README.md`, `# Blockchain Simulation Output\n\n**Collection:** ${collectionPhrase}\n**Tokens:** ${numTokens}\n**Years:** ${startYear} to ${startYear + numTokens - 1}\n\nGenerated: ${timestamp}\n\n## Files\n- \`combined-sequence.abc\` - ABC notation\n- \`combined-midi-info.json\` - MIDI data (convert with \`python convert-to-midi.py ${baseDir}\`)\n- \`token_metadata.csv\` - Token metadata\n`);
  
  console.log("\n=== Complete ===");
  console.log(`Generated ${numTokens} tokens`);
  console.log(`Output: ${baseDir}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
