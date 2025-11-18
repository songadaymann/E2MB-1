// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/Base64.sol";

import "./ILifeLens.sol";

library LifeToneScript {
    function generateScript(ILifeLens.LifeBoard memory board, string memory /* title */) internal pure returns (string memory) {
        string memory initialCells = _bytesToJSArray(board.initialCells);
        string memory leadSeq = _eventsToJS(board.leadPitches, board.leadDurations);
        string memory bassSeq = _eventsToJS(board.bassPitches, board.bassDurations);
        string memory markovCount = _toString(board.markovSteps);
        string memory baseSeed = _toString(board.baseSeed);
        string memory wordSeeds = _uintArrayToJS(board.wordSeeds);

        return string(
            abi.encodePacked(
                "const width=",
                _toString(board.width),
                ";const height=",
                _toString(board.height),
                ";const initialCells=",
                initialCells,
                ";const baseSeed=",
                baseSeed,
                ">>>0;",
                ";const currentRankRaw=",
                _toString(board.currentRank),
                ";const totalTokensRaw=",
                _toString(board.totalTokens),
                ";const revealTimestamp=",
                _toString(board.revealTimestamp),
                ";const tokenRevealed=",
                board.isRevealed ? "true" : "false",
                ";const secondsInYear=31557600;",
                ";const revealYearValue=",
                _toString(board.revealYear),
                ";const baseLeadSeq=",
                leadSeq,
                ";const baseBassSeq=",
                bassSeq,
                ";const unicodeNotes=[\"C\",\"D\\\\u266D\",\"D\",\"E\\\\u266D\",\"E\",\"F\",\"G\\\\u266D\",\"G\",\"A\\\\u266D\",\"A\",\"B\\\\u266D\",\"B\"];",
                "const asciiNotes=[\"C\",\"Db\",\"D\",\"Eb\",\"E\",\"F\",\"Gb\",\"G\",\"Ab\",\"A\",\"Bb\",\"B\"];",
                "const restUnicode=\"\\\\U0001D13D\";const restAscii=\"REST\";",
                "function formatNote(pitch){if(pitch<0)return{u:restUnicode,a:restAscii};const cls=((pitch%12)+12)%12;const octave=Math.floor(pitch/12)-1;return{u:unicodeNotes[cls]+octave,a:asciiNotes[cls]+octave};}",
                "const titleEl=document.getElementById('life-title');if(titleEl){titleEl.textContent='Life Lens';}",
                "const overlayEl=document.getElementById('life-overlay');",
                "const hideOverlay=()=>{if(overlayEl&&!overlayEl.classList.contains('overlay-hidden')){overlayEl.classList.add('overlay-hidden');}};",
                "const wordSeeds=",
                wordSeeds,
                ";const wordSeedCount=Math.max(1,wordSeeds.length);",
                "let wordCycle=0;",
                "const wordSalt=step=>wordSeeds[(wordCycle+step)%wordSeedCount]>>>0;",
                "const baseWordSalt=wordSalt(0);",
                ";let currentSeed=(baseSeed^baseWordSalt)>>>0;",
                "const glyphNodes=Array.from(document.querySelectorAll('.glyph'));",
                "const glyphPool=[\"\\u2669\",\"\\u266A\",\"\\u266B\",\"\\u266C\",\"\\u266D\",\"\\u266E\",\"\\u266F\",\"\\u{1D10C}\",\"\\u{1D10D}\",\"\\u{1D10E}\",\"\\u{1D10F}\",\"\\u{1D110}\",\"\\u{1D111}\",\"\\u{1D112}\",\"\\u{1D113}\",\"\\u{1D114}\",\"\\u{1D115}\",\"\\u{1D116}\",\"\\u{1D117}\",\"\\u{1D118}\",\"\\u{1D119}\",\"\\u{1D11A}\",\"\\u{1D11B}\",\"\\u{1D11C}\",\"\\u{1D11D}\",\"\\u{1D11E}\",\"\\u{1D11F}\",\"\\u{1D120}\",\"\\u{1D121}\",\"\\u{1D122}\",\"\\u{1D123}\",\"\\u{1D124}\",\"f\",\"\\u{1D18C}\",\"\\u{1D18D}\",\"\\u{1D18E}\",\"\\u{1D18F}\"];",
                "const glyphAssignments=new Array(initialCells.length);",
                "let glyphSeed=currentSeed||1;",
                "for(let i=0;i<initialCells.length;i++){glyphSeed=lcg(glyphSeed);glyphAssignments[i]=glyphPool[glyphSeed%glyphPool.length];if(glyphNodes[i]){glyphNodes[i].textContent=glyphAssignments[i];}}",
                ";const cellCount=initialCells.length;",
                ";const totalTokens=Math.max(totalTokensRaw,1);",
                "const currentRank=Math.min(currentRankRaw,totalTokens>0?totalTokens-1:currentRankRaw);",
                "let grid=initialCells.slice();let nextGrid=new Array(cellCount).fill(0);let idx=0;",
                "let currentLeadSeq=[];let currentBassSeq=[];",
                "const cells=Array.from(document.querySelectorAll('.cell'));",
                "const seenStates=new Set();",
                "const zeroState=\"0\".repeat(cellCount);",
                "const nowSeconds=Date.now()/1000;",
                "const yearsToReveal=tokenRevealed?0:Math.max(0,(revealTimestamp-nowSeconds)/secondsInYear);",
                "const chaosRank=totalTokens>1?currentRank/Math.max(totalTokens-1,1):0;",
                "const revealYearsRange=Math.max(1,totalTokens);",
                "const chaosTime=tokenRevealed?0:Math.min(1,(revealYearsRange-Math.min(revealYearsRange,yearsToReveal))/revealYearsRange);",
                "const chaos=tokenRevealed?0:Math.min(1,chaosRank*0.3+chaosTime*0.7);",
                "const calm=1-chaos;",
                "const aliveProbability=Math.min(0.95,0.15+0.8*chaos);",
                "const minAlive=Math.max(2,Math.round(3+chaos*17));",
                "const pitchShiftRange=Math.round(chaos*12);",
                "const durationVariance=0.2+chaos*1.0;",
                "const tickInterval=Math.max(220,Math.round(900-650*chaos));",
                "const PAD_NOTE_MIDI=63;",
                "const PAD_NOTE_FREQ=Tone.Frequency(PAD_NOTE_MIDI,'midi');",
                "let toneReady=false;let toneLoading=false;let pendingPrime=false;let lastPointerPrime=0;",
                "const leadDelay=new Tone.PingPongDelay('4t',0.6).toDestination();",
                "leadDelay.wet.value=0.1;",
                "const leadChorus=new Tone.Chorus(0.8,0.35,0.2).connect(leadDelay);",
                "leadChorus.wet.value=0.25;",
                "const leadSynth=new Tone.MonoSynth({volume:-35,oscillator:{type:'pulse',width:0.35},filter:{type:'lowpass',Q:0.7,rolloff:-48},filterEnvelope:{attack:0.023,decay:2.3,sustain:0.68,release:0.053,baseFrequency:200,octaves:4},envelope:{attack:0.0069,decay:0.23,sustain:1,release:0.2}}).connect(leadChorus);",
                "const bassReverb=new Tone.Reverb({preDelay:0.0128,decay:4.32,wet:0.45}).toDestination();",
                "const bassSynth=new Tone.MonoSynth({volume:-6,oscillator:{type:'triangle',partials:[1,0.5,0.25]},filter:{type:'lowpass',rolloff:-24,Q:0.2},filterEnvelope:{attack:0.008,decay:2.3,sustain:0.18,release:0.51,baseFrequency:90,octaves:2},envelope:{attack:0.013,decay:1, sustain:0.18, release:0.62}}).connect(bassReverb);",
                "const padSynth=new Tone.PolySynth(Tone.Synth,{volume:-35,oscillator:{type:'fatsawtooth',spread:15,count:4},filter:{type:'bandpass',rolloff:-12,Q:0.4},filterEnvelope:{attack:1.4,decay:4.2,sustain:0.4,release:2},envelope:{attack:1.5,decay:2.5,sustain:0.4,release:2.5}}).toDestination();",
                "let padActive=false;",
                "function startPadIfNeeded(){if(padActive||!toneReady)return;padSynth.triggerAttack(PAD_NOTE_FREQ,Tone.now(),0.5);padActive=true;}",
                "function triggerPrimePlayback(){pendingPrime=false;startPadIfNeeded();hideOverlay();const events=getEvents(idx);playEvents(events);}",
                "async function resumeAudioContext(){try{const ctx=(Tone.getContext?Tone.getContext():Tone.context);if(!ctx)return;const raw=ctx.rawContext||ctx; if(raw.state==='suspended'){await raw.resume();}}catch(err){console.warn('LifeLens resume failed',err);}}",
                "function ensureTone(){if(toneReady||toneLoading)return;toneLoading=true;Tone.start().then(()=>{toneReady=true;toneLoading=false;startPadIfNeeded();hideOverlay();if(pendingPrime){triggerPrimePlayback();}}).catch(err=>{toneLoading=false;console.warn('LifeLens Tone start failed',err);});}",
                "function playEvents(events){if(!toneReady)return;const now=Tone.now();if(events.lead&&events.lead.p>=0){leadSynth.triggerAttackRelease(Tone.Frequency(events.lead.p,'midi'),Math.max(0.15,(events.lead.d/480)*0.55),now);}if(events.bass&&events.bass.p>=0){bassSynth.triggerAttackRelease(Tone.Frequency(events.bass.p+12,'midi'),Math.max(0.2,(events.bass.d/480)*0.8),now);}}",
                "function render(){for(let i=0;i<grid.length;i++){const alive=grid[i];const cell=cells[i];if(cell){cell.style.opacity=alive?'0.08':'0';}const glyph=glyphNodes[i];if(glyph){glyph.style.opacity=alive?'1':'0';}}}",
                "function evolve(){for(let y=0;y<height;y++){for(let x=0;x<width;x++){let live=0;for(let dy=-1;dy<=1;dy++){for(let dx=-1;dx<=1;dx++){if(dx===0&&dy===0)continue;const nx=x+dx;const ny=y+dy;if(nx<0||ny<0||nx>=width||ny>=height)continue;const nIdx=ny*width+nx;live+=grid[nIdx];}}const index=y*width+x;const current=grid[index];nextGrid[index]=current?((live===2||live===3)?1:0):(live===3?1:0);}}const swap=grid;grid=nextGrid;nextGrid=swap;}",
                "function lcg(state){state=(Math.imul(state>>>0,1664525)+1013904223)>>>0;return state;}",
                "function seedGrid(seed){let state=(seed>>>0)||1;const out=new Array(cellCount);let alive=0;for(let i=0;i<out.length;i++){state=lcg(state);const aliveCell=((state&0xffff)/65535)<aliveProbability;out[i]=aliveCell?1:0;if(aliveCell)alive++;}if(alive<minAlive){for(let i=0;i<out.length&&alive<minAlive;i++){if(out[i]===0){out[i]=1;alive++;}}}return out;}",
                "function mutateSequence(base,seed,salt){let state=(seed^salt)>>>0;return base.map(ev=>{let pitch=ev.p;if(pitch>=0&&pitchShiftRange>0){state=lcg(state);const span=pitchShiftRange;const offset=((state>>>26)%(span*2+1))-span;pitch+=offset;}else{state=lcg(state);}state=lcg(state);let dur=ev.d;if(durationVariance>0){const tweak=(state>>>28)&3;if(tweak===1){dur=Math.max(60,Math.round(dur*(1-0.25*durationVariance)));}else if(tweak===2){dur=Math.min(960,Math.round(dur*(1+0.3*durationVariance)));}}return {p:pitch,d:dur};});}",
                "function updateSequences(){currentLeadSeq=mutateSequence(baseLeadSeq,currentSeed,101);currentBassSeq=mutateSequence(baseBassSeq,currentSeed,202);}",
                "function getEvents(step){return {lead:currentLeadSeq[step%currentLeadSeq.length],bass:currentBassSeq[step%currentBassSeq.length]};}",
                "function mixSeed(seed,gridArr,events,step){let state=(seed^0x9e3779b9^wordSalt(step))>>>0;for(let i=0;i<gridArr.length;i++){state=lcg(state ^ gridArr[i]);}state=lcg(state ^ ((events.lead.p&0xffff)>>>0));state=lcg(state ^ ((events.lead.d&0xffff)>>>0));state=lcg(state ^ ((events.bass.p&0xffff)>>>0));state=lcg(state ^ ((events.bass.d&0xffff)>>>0));state=lcg(state ^ (step>>>0));if(state===0)state=1;return state>>>0;}",
                "function resetLife(){wordCycle=(wordCycle+1)%wordSeedCount;const events=getEvents(idx);currentSeed=mixSeed(currentSeed,grid,events,idx);grid=seedGrid(currentSeed);nextGrid=new Array(cellCount).fill(0);seenStates.clear();updateSequences();idx=0;}",
                "function tick(){const key=grid.join(\"\");if(key===zeroState||seenStates.has(key)){resetLife();const events=getEvents(idx);render();playEvents(events);evolve();idx=(idx+1)%(",
                markovCount,
                ");return;}seenStates.add(key);const events=getEvents(idx);render();playEvents(events);evolve();idx=(idx+1)%(",
                markovCount,
                ");}",
                "const primeTone=async event=>{if(event&&event.type==='pointerdown'){lastPointerPrime=Date.now();}else if(event&&event.type==='click'&&Date.now()-lastPointerPrime<320){return;}if(overlayEl&&!toneReady){overlayEl.textContent='Loading audio...';overlayEl.classList.remove('overlay-hidden');}await resumeAudioContext();ensureTone();if(!toneReady){pendingPrime=true;return;}triggerPrimePlayback();};",
                "const registerPrimeTarget=target=>{if(!target)return;if(window.PointerEvent){target.addEventListener('pointerdown',primeTone,{passive:true});}else{target.addEventListener('touchstart',primeTone,{passive:true});target.addEventListener('mousedown',primeTone,{passive:true});}target.addEventListener('click',primeTone,{passive:true});};",
                "registerPrimeTarget(overlayEl);",
                "registerPrimeTarget(document);",
                "window.lifeLensPlay=()=>primeTone();",
                "updateSequences();render();setInterval(tick,tickInterval);"
            )
        );
    }

    function _toString(uint256 value) private pure returns (string memory) {
        if (value == 0) return "0";
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + value % 10));
            value /= 10;
        }
        return string(buffer);
    }

    function _intToString(int256 value) private pure returns (string memory) {
        if (value == 0) {
            return "0";
        }
        bool negative = value < 0;
        uint256 unsigned = uint256(negative ? -value : value);
        string memory str = _toString(unsigned);
        if (negative) {
            return string(abi.encodePacked("-", str));
        }
        return str;
    }

    function _bytesToJSArray(bytes memory data) private pure returns (string memory) {
        bytes memory out = "[";
        for (uint256 i = 0; i < data.length; i++) {
            out = abi.encodePacked(out, data[i] == bytes1(uint8(1)) ? "1" : "0");
            if (i + 1 < data.length) {
                out = abi.encodePacked(out, ",");
            }
        }
        out = abi.encodePacked(out, "]");
        return string(out);
    }

    function _eventsToJS(int16[] memory pitches, uint16[] memory durations) private pure returns (string memory) {
        require(pitches.length == durations.length, "LifeToneScript: pitch/duration mismatch");
        bytes memory out = "[";
        for (uint256 i = 0; i < pitches.length; i++) {
            out = abi.encodePacked(
                out,
                "{p:",
                _intToString(pitches[i]),
                ",d:",
                _toString(durations[i]),
                "}"
            );
            if (i + 1 < pitches.length) {
                out = abi.encodePacked(out, ",");
            }
        }
        out = abi.encodePacked(out, "]");
        return string(out);
    }

    function _pitchesToArray(int16[] memory pitches) private pure returns (string memory) {
        bytes memory out = "[";
        for (uint256 i = 0; i < pitches.length; i++) {
            out = abi.encodePacked(out, _intToString(pitches[i]));
            if (i + 1 < pitches.length) {
                out = abi.encodePacked(out, ",");
            }
        }
        out = abi.encodePacked(out, "]");
        return string(out);
    }

    function _uintArrayToJS(uint32[] memory values) private pure returns (string memory) {
        bytes memory out = "[";
        for (uint256 i = 0; i < values.length; i++) {
            out = abi.encodePacked(out, _toString(values[i]));
            if (i + 1 < values.length) {
                out = abi.encodePacked(out, ",");
            }
        }
        out = abi.encodePacked(out, "]");
        return string(out);
    }
}
