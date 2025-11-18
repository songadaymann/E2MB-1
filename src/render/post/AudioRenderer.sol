// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "../../interfaces/IAudioRenderer.sol";

contract AudioRenderer is IAudioRenderer {
    using Strings for uint256;
    
    function generateAudioHTML(
        int16 leadPitch,
        int16 bassPitch, 
        uint256 revealTimestamp,
        string memory svgContent
    ) external pure override returns (string memory) {
        string memory html = string(abi.encodePacked(
            '<!DOCTYPE html><html><head><meta charset="utf-8"><style>',
            'body{margin:0;padding:0;background:#000;display:flex;align-items:center;justify-content:center;min-height:100vh;cursor:pointer}',
            'svg{max-width:100%;max-height:100vh;display:block}',
            '</style></head><body onclick="toggle()">',
            svgContent,
            _generateScript(leadPitch, bassPitch),
            '</body></html>'
        ));
        
        return string(abi.encodePacked(
            'data:text/html;base64,',
            Base64.encode(bytes(html))
        ));
    }
    
    function _generateScript(
        int16 leadPitch,
        int16 bassPitch
    ) private pure returns (string memory) {
        string memory leadMidi = leadPitch == -1 ? "-1" : _int16ToString(leadPitch);
        string memory bassMidi = _int16ToString(bassPitch);
        
        return string(abi.encodePacked(
            '<script>',
            'let ctx,leadOscs=[],bassOscs=[];',
            'const LEAD_MIDI=', leadMidi, ';',
            'const BASS_MIDI=', bassMidi, ';',
            'function m2f(m){return 440*Math.pow(2,(m-69)/12)}',
            'function organ(f,oscs,master,amp){',
            'const g=ctx.createGain();',
            'g.gain.setValueAtTime(0,ctx.currentTime);',
            'g.gain.linearRampToValueAtTime(amp,ctx.currentTime+1.5);',
            'g.connect(master);',
            '[1,2,3].forEach((r,i)=>{',
            'const o=ctx.createOscillator();',
            'const h=ctx.createGain();',
            'o.frequency.value=f*r;',
            'h.gain.value=[0.5,0.3,0.2][i];',
            'o.connect(h).connect(g);',
            'o.start();',
            'oscs.push(o);',
            '});',
            '}',
            'function start(){',
            'if(ctx)return;',
            'ctx=new AudioContext();',
            'const master=ctx.createGain();',
            'master.gain.value=0.25;',
            'master.connect(ctx.destination);',
            'organ(m2f(BASS_MIDI),bassOscs,master,0.5);',
            'if(LEAD_MIDI!==-1){organ(m2f(LEAD_MIDI),leadOscs,master,0.4);}',
            '}',
            'function stop(){',
            'if(!ctx)return;',
            'leadOscs.forEach(o=>o.stop());',
            'bassOscs.forEach(o=>o.stop());',
            'ctx.close();',
            'ctx=null;leadOscs=[];bassOscs=[];',
            '}',
            'function toggle(){if(!ctx)start();else stop();}',
            '</script>'
        ));
    }
    
    function _int16ToString(int16 value) private pure returns (string memory) {
        if (value >= 0) {
            return Strings.toString(uint256(int256(value)));
        } else {
            return string(abi.encodePacked("-", Strings.toString(uint256(int256(-value)))));
        }
    }
}
