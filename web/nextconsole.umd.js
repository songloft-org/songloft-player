(function(k,S){typeof exports=="object"&&typeof module<"u"?S(exports):typeof define=="function"&&define.amd?define(["exports"],S):(k=typeof globalThis<"u"?globalThis:k||self,S(k.NextConsole={}))})(this,function(k){"use strict";let S=!1;function _(o){if(!S){S=!0;try{console.error("[NextConsole] event listener error",o)}finally{S=!1}}}class z{constructor(){this.listeners=new Map}on(e,t){return this.listeners.has(e)||this.listeners.set(e,new Set),this.listeners.get(e).add(t),()=>this.off(e,t)}off(e,t){this.listeners.get(e)?.delete(t)}emit(e,...t){this.listeners.get(e)?.forEach(n=>{try{n(...t)}catch(s){_(s)}})}removeAllListeners(){this.listeners.clear()}}function B(o){const e=new Date(o),t=String(e.getHours()).padStart(2,"0"),n=String(e.getMinutes()).padStart(2,"0"),s=String(e.getSeconds()).padStart(2,"0"),r=String(e.getMilliseconds()).padStart(3,"0");return`${t}:${n}:${s}.${r}`}function I(o){return o<1?"<1ms":o<1e3?`${Math.round(o)}ms`:`${(o/1e3).toFixed(2)}s`}let W=0;function $(){return++W}const J={maxLogs:1e4,hookConsole:!0},D=["log","info","warn","error","debug"];class Y extends z{constructor(e){super(),this.entries=[],this.originals=new Map,this.hooked=!1,this.streamBuffers=new Map,this.flushTimer=null,this.pendingStreamEntries=new Set,this.options={...J,...e}}init(){if(!this.hooked&&this.options.hookConsole){for(const e of D){const t=console[e].bind(console);this.originals.set(e,t),console[e]=(...n)=>{t(...n),this.addEntry(e,n)}}this.hooked=!0}}addEntry(e,t){let n;(e==="error"||e==="warn")&&(n=new Error().stack?.split(`
`).slice(3).join(`
`));const s={id:$(),level:e,args:this.cloneArgs(t),timestamp:Date.now(),stack:n};this.entries.push(s),this.entries.length>this.options.maxLogs&&this.entries.splice(0,this.entries.length-this.options.maxLogs),this.emit("entry",s)}appendStream(e,t){let n=this.streamBuffers.get(e);n?(n.args=[n.args[0]+t],this.scheduleStreamFlush(n)):(n={id:$(),level:"log",args:[t],timestamp:Date.now(),streamId:e,streaming:!0},this.streamBuffers.set(e,n),this.entries.push(n),this.emit("entry",n))}endStream(e){const t=this.streamBuffers.get(e);t&&(t.streaming=!1,this.streamBuffers.delete(e),this.emit("streamUpdate",t))}scheduleStreamFlush(e){this.pendingStreamEntries.add(e),this.flushTimer===null&&(this.flushTimer=requestAnimationFrame(()=>{this.flushTimer=null;for(const t of this.pendingStreamEntries)this.emit("streamUpdate",t);this.pendingStreamEntries.clear()}))}cloneArgs(e){return e.map(t=>{if(t instanceof Error)return{message:t.message,stack:t.stack,name:t.name};if(t instanceof HTMLElement)return`<${t.tagName.toLowerCase()}>`;if(t instanceof Date)return t.toISOString();if(t instanceof RegExp)return t.toString();if(t instanceof Map)try{return{__type:"Map",entries:JSON.parse(JSON.stringify([...t]))}}catch{return`Map(${t.size})`}if(t instanceof Set)try{return{__type:"Set",values:JSON.parse(JSON.stringify([...t]))}}catch{return`Set(${t.size})`}if(typeof t=="symbol")return t.toString();if(typeof t=="function")return`ƒ ${t.name||"anonymous"}()`;if(typeof t=="object"&&t!==null)try{return JSON.parse(JSON.stringify(t))}catch{return String(t)}return t})}getEntries(){return this.entries}getFilteredEntries(e,t){let n=this.entries;if(e&&e.length>0&&(n=n.filter(s=>e.includes(s.level))),t){const s=t.toLowerCase();n=n.filter(r=>r.args.some(i=>String(i).toLowerCase().includes(s)))}return n}clear(){this.entries.length=0,this.streamBuffers.clear(),this.emit("clear")}exportJSON(){return JSON.stringify(this.entries,null,2)}destroy(){if(this.hooked){for(const e of D){const t=this.originals.get(e);t&&(console[e]=t)}this.originals.clear(),this.hooked=!1,this.flushTimer!==null&&cancelAnimationFrame(this.flushTimer),this.pendingStreamEntries.clear(),this.removeAllListeners()}}}const V={maxRequests:500,hookFetch:!0,hookXHR:!0,hookSSE:!0,hookWebSocket:!0,previewFetchResponseBody:!1},N=1e3,F=1e4,G=1e4,K=["text/event-stream","application/x-ndjson","application/json-seq","application/jsonl"],Q=["application/octet-stream","application/pdf","application/zip","application/gzip","application/x-tar","application/x-7z-compressed"];function O(o){return typeof Request<"u"&&o instanceof Request}function Z(o){return typeof o=="string"?o:o instanceof URL?o.href:o.url}function ee(o,e){return(e?.method||(O(o)?o.method:"GET")).toUpperCase()}function te(o,e){const t=new Headers(O(o)?o.headers:void 0);e?.headers&&new Headers(e.headers).forEach((s,r)=>t.set(r,s));const n={};return t.forEach((s,r)=>n[r]=s),n}function A(o){return typeof o=="boolean"?o:!!o?.capture}function ne(o){const e=o.headers.get("content-length");if(!e)return null;const t=Number(e);return Number.isFinite(t)&&t>=0?t:null}function X(o){if(o==null)return null;if(typeof o=="string")return o;if(typeof URLSearchParams<"u"&&o instanceof URLSearchParams)return o.toString();if(typeof FormData<"u"&&o instanceof FormData){const e={};return o.forEach((t,n)=>{e[n]=typeof t=="string"?t:`[File: ${t.name}]`}),e}return typeof Blob<"u"&&o instanceof Blob?`[Blob: ${o.size} bytes]`:o instanceof ArrayBuffer?`[ArrayBuffer: ${o.byteLength} bytes]`:ArrayBuffer.isView(o)?`[${o.constructor.name}: ${o.byteLength} bytes]`:String(o)}function se(o){const e=o.responseType||"text";if(e==="json")return o.response;if(e==="blob"){const t=o.response;return t?`[Blob: ${t.size} bytes]`:"[Blob]"}if(e==="arraybuffer"){const t=o.response;return t?`[ArrayBuffer: ${t.byteLength} bytes]`:"[ArrayBuffer]"}if(e==="document"){const t=o.response;return t?`[Document: ${t.contentType||"unknown"}]`:"[Document]"}try{const t=o.getResponseHeader("content-type")||"",n=o.responseText||"",s=n.length>F?`${n.slice(0,F)}...(truncated)`:n;if(t.includes("application/json"))try{return JSON.parse(n)}catch{return s}return s}catch{return"[Unable to read body]"}}class re extends z{constructor(e){super(),this.entries=[],this.originalFetch=null,this.originalXHR=null,this.originalXHRSend=null,this.originalXHRSetHeader=null,this.originalEventSource=null,this.originalWebSocket=null,this.scheduledStreamUpdates=new Map,this.hooked=!1,this.options={...V,...e}}init(){this.hooked||(this.options.hookFetch&&this.hookFetch(),this.options.hookXHR&&this.hookXHR(),this.options.hookSSE&&this.hookSSE(),this.options.hookWebSocket&&this.hookWebSocket(),this.hooked=!0)}hookFetch(){this.originalFetch=window.fetch.bind(window);const e=this,t=this.originalFetch;window.fetch=async function(n,s){const r=Z(n),i=ee(n,s),a=te(n,s),l={id:$(),type:"fetch",method:i,url:r,requestHeaders:a,requestBody:X(s?.body),status:0,statusText:"",responseHeaders:{},responseBody:null,startTime:performance.now(),endTime:0,duration:0,pending:!0};e.addEntry(l);try{const c=await t(n,s);return l.status=c.status,l.statusText=c.statusText,c.headers.forEach((u,d)=>l.responseHeaders[d]=u),l.endTime=performance.now(),l.duration=l.endTime-l.startTime,l.pending=!1,e.options.previewFetchResponseBody||(l.responseBody="[Fetch response body preview disabled]"),e.emit("update",l),e.options.previewFetchResponseBody&&e.scheduleFetchBodyCapture(c,l,i),c}catch(c){throw l.endTime=performance.now(),l.duration=l.endTime-l.startTime,l.pending=!1,l.error=c instanceof Error?c.message:String(c),e.emit("update",l),c}}}scheduleFetchBodyCapture(e,t,n){window.setTimeout(()=>{this.captureFetchBody(e,t,n)},0)}async captureFetchBody(e,t,n){const s=this.getBodySkipReason(e,n);if(s===null)return;if(s){t.responseBody=s,this.emit("update",t);return}let r;try{r=e.clone()}catch{t.responseBody="[Unable to read body]",this.emit("update",t);return}try{const i=e.headers.get("content-type")?.toLowerCase()||"",a=await this.readTextPreview(r,F),l=a.truncated?`${a.text}...(truncated)`:a.text;if(!a.truncated&&i.includes("json"))try{t.responseBody=JSON.parse(a.text)}catch{t.responseBody=l}else t.responseBody=l}catch{t.responseBody="[Unable to read body]"}this.emit("update",t)}getBodySkipReason(e,t){if(t==="HEAD"||[204,205,304].includes(e.status)||!e.body)return null;if(e.bodyUsed||e.body.locked)return"[Response body consumed by page]";const n=e.headers.get("content-type")?.toLowerCase()||"";if(K.some(r=>n.includes(r))||n.includes("stream"))return"[Streaming response body omitted]";if(n.startsWith("image/")||n.startsWith("audio/")||n.startsWith("video/")||n.startsWith("font/")||Q.some(r=>n.includes(r)))return"[Binary response body omitted]";const s=ne(e);if(s===null)return"[Response body preview skipped: unknown size]";if(s===0)return null;if(s>G)return`[Response body omitted: ${s} bytes]`}async readTextPreview(e,t){if(!e.body)return{text:"",truncated:!1};const n=e.body.getReader(),s=new TextDecoder;let r="",i=!1;try{for(;;){const{done:a,value:l}=await n.read();if(a)break;if(r+=s.decode(l,{stream:!0}),r.length>t){r=r.slice(0,t),i=!0,await n.cancel();break}}i||(r+=s.decode())}finally{try{n.releaseLock()}catch{}}return{text:r,truncated:i}}pushSSEEvent(e,t){const n=e.sseEvents;n&&(n.length>=N&&n.splice(0,n.length-N+100),n.push(t))}pushStreamMessage(e,t){const n=e.messages;n&&(n.length>=N&&n.splice(0,n.length-N+100),n.push(t),this.scheduleStreamUpdate(e))}scheduleStreamUpdate(e){if(this.scheduledStreamUpdates.has(e.id))return;const t=()=>{this.scheduledStreamUpdates.delete(e.id),this.emit("update",e)};if(typeof window.requestAnimationFrame=="function"){const s=window.requestAnimationFrame(t);this.scheduledStreamUpdates.set(e.id,{type:"raf",handle:s});return}const n=window.setTimeout(t,16);this.scheduledStreamUpdates.set(e.id,{type:"timeout",handle:n})}cancelScheduledStreamUpdate(e){const t=this.scheduledStreamUpdates.get(e.id);t&&(t.type==="raf"?window.cancelAnimationFrame(t.handle):window.clearTimeout(t.handle),this.scheduledStreamUpdates.delete(e.id))}emitUpdateNow(e){this.cancelScheduledStreamUpdate(e),this.emit("update",e)}hookXHR(){const e=this,t=XMLHttpRequest.prototype.open,n=XMLHttpRequest.prototype.send,s=XMLHttpRequest.prototype.setRequestHeader;this.originalXHR=t,this.originalXHRSend=n,this.originalXHRSetHeader=s,XMLHttpRequest.prototype.open=function(r,i){return this._nc_headers={},this._nc_entry={id:$(),type:"xhr",method:r.toUpperCase(),url:String(i),requestHeaders:this._nc_headers,requestBody:null,status:0,statusText:"",responseHeaders:{},responseBody:null,startTime:0,endTime:0,duration:0,pending:!0},t.apply(this,arguments)},XMLHttpRequest.prototype.setRequestHeader=function(r,i){return this._nc_headers&&(this._nc_headers[r]=i),s.call(this,r,i)},XMLHttpRequest.prototype.send=function(r){const i=this._nc_entry;return i&&(i.startTime=performance.now(),i.requestBody=X(r),e.addEntry(i),this.addEventListener("loadend",()=>{i.status=this.status,i.statusText=this.statusText,i.endTime=performance.now(),i.duration=i.endTime-i.startTime,i.pending=!1;const a=this.getAllResponseHeaders();a&&a.split(`\r
`).forEach(l=>{const c=l.indexOf(":");c>0&&(i.responseHeaders[l.slice(0,c).trim()]=l.slice(c+1).trim())}),i.responseBody=se(this),e.emit("update",i)}),this.addEventListener("error",()=>{i.endTime=performance.now(),i.duration=i.endTime-i.startTime,i.pending=!1,i.error="Network Error",e.emit("update",i)})),n.call(this,r)}}hookSSE(){if(typeof EventSource>"u")return;const e=this,t=EventSource;this.originalEventSource=t;const n=function(s,r){const i=new t(s,r),a={id:$(),type:"sse",method:"GET",url:String(s),requestHeaders:{},requestBody:null,status:0,statusText:"SSE",responseHeaders:{},responseBody:null,startTime:performance.now(),endTime:0,duration:0,pending:!0,sseEvents:[],messages:[]};e.addEntry(a),i.addEventListener("open",()=>{a.status=200,e.emit("update",a)});const l=i.addEventListener.bind(i),c=i.removeEventListener.bind(i),u=new Map;return i.addEventListener=function(d,f,g){if(!f)return l(d,f,g);if(d!=="open"&&d!=="error"&&d!=="message"){const x=A(g);let w=u.get(d);w||(w=new WeakMap,u.set(d,w));let y=w.get(f);y||(y=new Map,w.set(f,y));let T=y.get(x);return T||(T=function(L){const E=L,p={data:E.data,timestamp:Date.now(),id:E.lastEventId||void 0,event:d};e.pushSSEEvent(a,p);const b={direction:"in",data:E.data,timestamp:Date.now(),event:d,size:typeof E.data=="string"?E.data.length:0};e.pushStreamMessage(a,b),typeof f=="function"?f.call(i,L):f.handleEvent(L)},y.set(x,T)),l(d,T,g)}return l(d,f,g)},i.removeEventListener=function(d,f,g){if(f&&d!=="open"&&d!=="error"&&d!=="message"){const x=u.get(d),w=x?.get(f),y=w?.get(A(g));if(y)return w?.delete(A(g)),w?.size===0&&x?.delete(f),c(d,y,g)}return c(d,f,g)},l("message",d=>{const f={data:d.data,timestamp:Date.now(),id:d.lastEventId||void 0};e.pushSSEEvent(a,f);const g={direction:"in",data:d.data,timestamp:Date.now(),size:typeof d.data=="string"?d.data.length:0};e.pushStreamMessage(a,g)}),i.addEventListener("error",()=>{a.pending=!1,a.endTime=performance.now(),a.duration=a.endTime-a.startTime,a.error="SSE Connection Error",e.emitUpdateNow(a)}),i};Object.defineProperties(n,{CONNECTING:{value:t.CONNECTING},OPEN:{value:t.OPEN},CLOSED:{value:t.CLOSED},prototype:{value:t.prototype}}),window.EventSource=n}hookWebSocket(){if(typeof WebSocket>"u")return;const e=this,t=WebSocket;this.originalWebSocket=t;const n=function(s,r){const i=new t(s,r),a={id:$(),type:"websocket",method:"WS",url:String(s),requestHeaders:{},requestBody:null,status:0,statusText:"WebSocket",responseHeaders:{},responseBody:null,startTime:performance.now(),endTime:0,duration:0,pending:!0,messages:[]};e.addEntry(a),i.addEventListener("open",()=>{a.status=101,a.statusText="Switching Protocols",e.emit("update",a)}),i.addEventListener("message",c=>{const d={direction:"in",data:typeof c.data=="string"?c.data:"[Binary]",timestamp:Date.now(),size:typeof c.data=="string"?c.data.length:c.data?.byteLength||0};e.pushStreamMessage(a,d)}),i.addEventListener("close",c=>{a.pending=!1,a.endTime=performance.now(),a.duration=a.endTime-a.startTime,a.statusText=`Closed (${c.code})`,e.emitUpdateNow(a)}),i.addEventListener("error",()=>{a.pending=!1,a.endTime=performance.now(),a.duration=a.endTime-a.startTime,a.error="WebSocket Error",e.emitUpdateNow(a)});const l=i.send.bind(i);return i.send=function(c){const d={direction:"out",data:typeof c=="string"?c:"[Binary]",timestamp:Date.now(),size:typeof c=="string"?c.length:c?.byteLength||0};return e.pushStreamMessage(a,d),l(c)},i};Object.defineProperties(n,{CONNECTING:{value:t.CONNECTING},OPEN:{value:t.OPEN},CLOSING:{value:t.CLOSING},CLOSED:{value:t.CLOSED},prototype:{value:t.prototype}}),window.WebSocket=n}addEntry(e){this.entries.push(e),this.entries.length>this.options.maxRequests&&this.entries.splice(0,this.entries.length-this.options.maxRequests),this.emit("request",e)}getEntries(){return this.entries}clear(){this.entries.length=0,this.emit("clear")}destroy(){this.hooked&&(this.scheduledStreamUpdates.forEach(e=>{e.type==="raf"?window.cancelAnimationFrame(e.handle):window.clearTimeout(e.handle)}),this.scheduledStreamUpdates.clear(),this.originalFetch&&(window.fetch=this.originalFetch),this.originalXHR&&(XMLHttpRequest.prototype.open=this.originalXHR),this.originalXHRSend&&(XMLHttpRequest.prototype.send=this.originalXHRSend),this.originalXHRSetHeader&&(XMLHttpRequest.prototype.setRequestHeader=this.originalXHRSetHeader),this.originalEventSource&&(window.EventSource=this.originalEventSource),this.originalWebSocket&&(window.WebSocket=this.originalWebSocket),this.hooked=!1,this.removeAllListeners())}}const oe={showLocalStorage:!0,showSessionStorage:!0,showCookies:!0};class ie extends z{constructor(e){super(),this.options={...oe,...e}}init(){}getEntries(e){const t=[];return this.options.showLocalStorage&&t.push(...this.readWebStorage("localStorage",e)),this.options.showSessionStorage&&t.push(...this.readWebStorage("sessionStorage",e)),this.options.showCookies&&t.push(...this.readCookies(e)),t}readWebStorage(e,t){const n=[];try{const s=e==="localStorage"?localStorage:sessionStorage;for(let r=0;r<s.length;r++){const i=s.key(r);i!==null&&(t&&!i.toLowerCase().includes(t.toLowerCase())||n.push({key:i,value:s.getItem(i)||"",type:e}))}}catch{}return n}readCookies(e){const t=[],n=document.cookie;if(!n)return t;const s=n.split(";");for(const r of s){const i=r.indexOf("=");if(i<0)continue;const a=r.slice(0,i).trim(),l=r.slice(i+1).trim();if(e&&!a.toLowerCase().includes(e.toLowerCase()))continue;let c;try{c=decodeURIComponent(l)}catch{c=l}t.push({key:a,value:c,type:"cookie"})}return t}setItem(e,t,n,s){let r=!1;try{if(e==="localStorage")localStorage.setItem(t,n),r=!0;else if(e==="sessionStorage")sessionStorage.setItem(t,n),r=!0;else if(e==="cookie"){let i=`${encodeURIComponent(t)}=${encodeURIComponent(n)}`;s?.domain&&(i+=`; domain=${s.domain}`),s?.path?i+=`; path=${s.path}`:i+="; path=/",s?.expires&&(i+=`; expires=${s.expires}`),s?.secure&&(i+="; secure"),s?.sameSite&&(i+=`; SameSite=${s.sameSite}`),document.cookie=i,r=this.readCookies().some(a=>a.key===t&&a.value===n)}}catch{}return this.emit("update"),r}removeItem(e,t){try{if(e==="localStorage")localStorage.removeItem(t);else if(e==="sessionStorage")sessionStorage.removeItem(t);else if(e==="cookie"){const n=["/",window.location.pathname];for(const s of n)document.cookie=`${encodeURIComponent(t)}=; expires=Thu, 01 Jan 1970 00:00:00 GMT; path=${s}`}}catch{}this.emit("update")}clearAll(e){try{if(e==="localStorage")localStorage.clear();else if(e==="sessionStorage")sessionStorage.clear();else if(e==="cookie"){const t=this.readCookies();for(const n of t)this.removeItem("cookie",n.key)}}catch{}this.emit("update")}destroy(){this.removeAllListeners()}}const ae="nc-";function m(...o){return o.map(e=>`${ae}${e}`).join(" ")}function v(o,e,t,n){return o.addEventListener(e,t,n),()=>o.removeEventListener(e,t,n)}function C(o,e,t){return Math.max(e,Math.min(t,o))}function h(o){return o.replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;").replace(/"/g,"&quot;").replace(/'/g,"&#39;")}class ce{constructor(){this.highlightOverlay=null}init(){this.highlightOverlay=document.createElement("div"),Object.assign(this.highlightOverlay.style,{position:"fixed",zIndex:"2147483646",pointerEvents:"none",border:"2px solid #61dafb",backgroundColor:"rgba(97, 218, 251, 0.1)",display:"none"}),document.body.appendChild(this.highlightOverlay)}renderTree(e=document.documentElement,t=8){return this.renderNode(e,0,t)}renderNode(e,t,n){if(t>=n)return`<div class="${m("dom-node")}" style="padding-left:${t*16}px">...</div>`;const s=e.tagName.toLowerCase(),r=this.renderAttributes(e),i=e.children.length>0,a=`nc-dom-${t}-${s}-${Math.random().toString(36).slice(2,8)}`,l=h(this.getSelector(e));let c="";if(i){c+=`<div class="${m("dom-node","dom-collapsible")}" style="padding-left:${t*16}px">`,c+=`<span class="${m("dom-toggle")}" data-nc-toggle="${a}">▶</span> `,c+=`<span class="${m("dom-tag")}" data-nc-highlight="${l}">&lt;${h(s)}</span>`,c+=r,c+=`<span class="${m("dom-tag")}">&gt;</span>`,c+="</div>",c+=`<div class="${m("dom-children")}" id="${a}" style="display:none">`;for(let u=0;u<e.children.length;u++)c+=this.renderNode(e.children[u],t+1,n);c+=`<div class="${m("dom-node")}" style="padding-left:${t*16}px">`,c+=`<span class="${m("dom-tag")}">&lt;/${h(s)}&gt;</span>`,c+="</div>",c+="</div>"}else{const u=e.textContent?.trim(),d=u&&u.length>0?h(u.slice(0,60)):"";c+=`<div class="${m("dom-node")}" style="padding-left:${t*16}px">`,c+=`<span class="${m("dom-tag")}" data-nc-highlight="${l}">&lt;${h(s)}</span>`,c+=r,d?(c+=`<span class="${m("dom-tag")}">&gt;</span>`,c+=`<span class="${m("dom-text")}">${d}</span>`,c+=`<span class="${m("dom-tag")}">&lt;/${h(s)}&gt;</span>`):c+=`<span class="${m("dom-tag")}">/&gt;</span>`,c+="</div>"}return c}renderAttributes(e){let t="";for(let n=0;n<e.attributes.length;n++){const s=e.attributes[n];t+=` <span class="${m("dom-attr")}">${h(s.name)}</span>`,t+=`=<span class="${m("dom-attr-val")}">"${h(s.value.slice(0,80))}"</span>`}return t}getSelector(e){if(e.id)return`#${CSS.escape(e.id)}`;const t=e.tagName.toLowerCase();if(e.className&&typeof e.className=="string"){const n=e.className.split(" ").filter(Boolean).map(s=>CSS.escape(s)).join(".");return n?`${t}.${n}`:t}return t}highlight(e){if(this.highlightOverlay)try{const t=document.querySelector(e);if(!t){this.clearHighlight();return}const n=t.getBoundingClientRect();Object.assign(this.highlightOverlay.style,{display:"block",top:`${n.top}px`,left:`${n.left}px`,width:`${n.width}px`,height:`${n.height}px`})}catch{this.clearHighlight()}}clearHighlight(){this.highlightOverlay&&(this.highlightOverlay.style.display="none")}destroy(){this.highlightOverlay&&this.highlightOverlay.parentNode&&this.highlightOverlay.parentNode.removeChild(this.highlightOverlay),this.highlightOverlay=null}}let le=0;class de extends z{constructor(){super(...arguments),this.entries=[],this.history=[],this.maxHistory=100}addEntry(e,t){const n={id:++le,type:e,content:t,timestamp:Date.now()};return this.entries.push(n),this.emit("entry",n),n}execute(e){if(e.trim()){this.addEntry("input",e),this.history.push(e),this.history.length>this.maxHistory&&this.history.shift();try{const n=(0,eval)(e);this.addEntry("output",this.formatResult(n))}catch(t){const n=t instanceof Error?t.message:String(t);this.addEntry("error",n)}}}formatResult(e){if(e===void 0)return"undefined";if(e===null)return"null";if(typeof e=="function")return`ƒ ${e.name||"anonymous"}()`;if(typeof e=="symbol")return e.toString();if(e instanceof Error)return`${e.name}: ${e.message}`;if(e instanceof HTMLElement)return`<${e.tagName.toLowerCase()}>`;if(e instanceof NodeList)return`NodeList(${e.length})`;if(typeof e=="object")try{return JSON.stringify(e,null,2)}catch{return String(e)}return String(e)}getEntries(){return this.entries}getHistory(){return this.history}clear(){this.entries.length=0,this.emit("clear")}destroy(){this.removeAllListeners()}}class he{constructor(e,t,n){this.container=e,this.onClick=t,this.cleanups=[],this.isDragging=!1,this.dragStarted=!1,this.startX=0,this.startY=0,this.offsetX=0,this.offsetY=0,this.currentX=0,this.currentY=0,this.snapTimer=null,this.el=document.createElement("button"),this.el.className="nc-float-btn",this.el.textContent="NC",this.el.setAttribute("aria-label","Toggle NextConsole");const s=n?.x??window.innerWidth-64,r=n?.y??window.innerHeight-100;this.setPosition(s,r),e.appendChild(this.el),this.bindEvents()}setPosition(e,t){const n=window.innerWidth-48,s=window.innerHeight-48;this.currentX=C(e,0,n),this.currentY=C(t,0,s),this.el.style.left=`${this.currentX}px`,this.el.style.top=`${this.currentY}px`}bindEvents(){this.cleanups.push(v(this.el,"touchstart",t=>{t.preventDefault(),this.isDragging=!0,this.dragStarted=!1;const n=t.touches[0];this.startX=n.clientX,this.startY=n.clientY,this.offsetX=this.el.offsetLeft,this.offsetY=this.el.offsetTop},{passive:!1})),this.cleanups.push(v(window,"touchmove",t=>{if(!this.isDragging)return;const n=t.touches[0],s=n.clientX-this.startX,r=n.clientY-this.startY;!this.dragStarted&&Math.abs(s)+Math.abs(r)>5&&(this.dragStarted=!0),this.dragStarted&&this.setPosition(this.offsetX+s,this.offsetY+r)},{passive:!0})),this.cleanups.push(v(window,"touchend",()=>{this.isDragging&&(this.dragStarted?this.snapToEdge():this.onClick(),this.isDragging=!1,this.dragStarted=!1)})),this.cleanups.push(v(this.el,"mousedown",t=>{t.preventDefault(),this.isDragging=!0,this.dragStarted=!1,this.startX=t.clientX,this.startY=t.clientY,this.offsetX=this.el.offsetLeft,this.offsetY=this.el.offsetTop})),this.cleanups.push(v(window,"mousemove",t=>{if(!this.isDragging)return;const n=t.clientX-this.startX,s=t.clientY-this.startY;!this.dragStarted&&Math.abs(n)+Math.abs(s)>5&&(this.dragStarted=!0),this.dragStarted&&this.setPosition(this.offsetX+n,this.offsetY+s)})),this.cleanups.push(v(window,"mouseup",()=>{this.isDragging&&(this.dragStarted?this.snapToEdge():this.onClick(),this.isDragging=!1,this.dragStarted=!1)}));const e=()=>{this.setPosition(this.currentX,this.currentY)};this.cleanups.push(v(window,"resize",e),v(window,"orientationchange",e))}snapToEdge(){const e=this.el.offsetLeft,t=window.innerWidth/2,n=C(e<t?8:window.innerWidth-56,0,window.innerWidth-48);this.currentX=n,this.el.style.transition="left 0.2s ease",this.el.style.left=`${n}px`,this.snapTimer!==null&&clearTimeout(this.snapTimer),this.snapTimer=setTimeout(()=>{this.el.style.transition="",this.snapTimer=null},200)}show(){this.el.style.display="flex"}hide(){this.el.style.display="none"}destroy(){this.snapTimer!==null&&(clearTimeout(this.snapTimer),this.snapTimer=null),this.cleanups.forEach(e=>e()),this.cleanups.length=0,this.el.remove()}}const pe={key:"#9cdcfe",string:"#ce9178",number:"#b5cea8",boolean:"#569cd6",null:"#569cd6",bracket:"#d4d4d4",comma:"#d4d4d4"};function R(o,e=4){const t=new WeakSet;function n(r,i){if(i>e)return s("string",'"[...]"');if(r===null)return s("null","null");if(r===void 0)return s("null","undefined");const a=typeof r;if(a==="string")return s("string",`"${h(r)}"`);if(a==="number"||a==="bigint")return s("number",String(r));if(a==="boolean")return s("boolean",String(r));if(a==="function")return s("string",`"ƒ ${r.name||"anonymous"}()"`);if(a==="symbol")return s("string",`"${String(r)}"`);if(typeof r=="object"){if(t.has(r))return s("string",'"[Circular]"');if(t.add(r),Array.isArray(r)){if(r.length===0)return s("bracket","[]");const f=r.map(g=>n(g,i+1)).join(s("comma",", "));return s("bracket","[")+f+s("bracket","]")}const l=r,c=Object.keys(l);if(c.length===0)return s("bracket","{}");const u=c.slice(0,100).map(f=>{const g=s("key",`"${h(f)}"`),x=n(l[f],i+1);return`${g}: ${x}`}).join(s("comma",", ")),d=c.length>100?s("comma",`, ... +${c.length-100}`):"";return s("bracket","{")+u+d+s("bracket","}")}return s("string",h(String(r)))}function s(r,i){return`<span style="color:${pe[r]}">${i}</span>`}return n(o,0)}const ue=500;class fe{constructor(e,t){this.filteredEntries=[],this.activeFilters=new Set,this.searchText="",this.scrollLocked=!0,this.renderRAF=null,this.needsRefresh=!1,this.cleanups=[],this.container=e,this.core=t,this.render(),this.bindEvents()}render(){this.toolbarEl=document.createElement("div"),this.toolbarEl.className="nc-toolbar nc-console-toolbar",this.toolbarEl.innerHTML=`
      <div class="nc-toolbar-group nc-console-filter-group">
        <button class="nc-toolbar-btn" data-nc-filter="log">Log</button>
        <button class="nc-toolbar-btn" data-nc-filter="info">Info</button>
        <button class="nc-toolbar-btn" data-nc-filter="warn">Warn</button>
        <button class="nc-toolbar-btn" data-nc-filter="error">Error</button>
        <button class="nc-toolbar-btn" data-nc-filter="debug">Debug</button>
      </div>
      <input type="text" placeholder="Filter logs..." class="nc-console-search" />
      <div class="nc-toolbar-group nc-console-action-group">
        <button class="nc-toolbar-btn nc-console-clear">Clear</button>
        <button class="nc-toolbar-btn nc-console-export">Export</button>
      </div>
    `,this.container.appendChild(this.toolbarEl),this.listEl=document.createElement("div"),this.listEl.className="nc-console-list",this.container.appendChild(this.listEl),this.refreshEntries()}bindEvents(){this.toolbarEl.addEventListener("click",i=>{const a=i.target.closest("[data-nc-filter]");if(a){const l=a.getAttribute("data-nc-filter");this.activeFilters.has(l)?(this.activeFilters.delete(l),a.classList.remove("nc-active")):(this.activeFilters.add(l),a.classList.add("nc-active")),this.refreshEntries()}});const e=this.toolbarEl.querySelector(".nc-console-search");let t;e.addEventListener("input",()=>{clearTimeout(t),t=setTimeout(()=>{this.searchText=e.value,this.refreshEntries()},150)}),this.toolbarEl.querySelector(".nc-console-clear").addEventListener("click",()=>{this.core.clear()}),this.toolbarEl.querySelector(".nc-console-export").addEventListener("click",()=>{const i=this.core.exportJSON(),a=new Blob([i],{type:"application/json"}),l=URL.createObjectURL(a),c=document.createElement("a");c.href=l,c.download=`nextconsole-logs-${Date.now()}.json`,c.click(),URL.revokeObjectURL(l)}),this.listEl.addEventListener("scroll",()=>{const{scrollTop:i,scrollHeight:a,clientHeight:l}=this.listEl;this.scrollLocked=i+l>=a-40});const n=this.core.on("entry",()=>{this.scheduleRefresh()}),s=this.core.on("streamUpdate",()=>{this.scheduleRefresh()}),r=this.core.on("clear",()=>{this.scheduleRefresh()});this.cleanups.push(n,s,r)}scheduleRefresh(){if(!this.isRenderable()){this.needsRefresh=!0;return}this.renderRAF===null&&(this.renderRAF=requestAnimationFrame(()=>{this.renderRAF=null,this.refreshEntries()}))}refresh(){this.renderRAF!==null&&(cancelAnimationFrame(this.renderRAF),this.renderRAF=null),this.needsRefresh=!1,this.refreshEntries()}isRenderable(){return this.container.classList.contains("nc-tab-pane-active")&&this.container.closest(".nc-panel-visible")!==null}refreshEntries(){if(!this.isRenderable()&&this.needsRefresh)return;const e=this.activeFilters.size>0?Array.from(this.activeFilters):void 0;this.filteredEntries=this.core.getFilteredEntries(e,this.searchText||void 0),this.renderList()}renderList(){const e=this.filteredEntries,t=Math.max(0,e.length-ue);let n="";t>0&&(n+=`<div class="nc-log-entry" style="justify-content:center;color:var(--nc-text-muted);font-size:11px">... 省略了 ${t} 条更早的日志 ...</div>`);for(let s=t;s<e.length;s++){const r=e[s],i=r.streaming?" nc-log-streaming":"";n+=`<div class="nc-log-entry nc-log-level-${r.level}${i}">`,n+=`<span class="nc-log-time">${B(r.timestamp)}</span>`,n+=`<span class="nc-log-body">${this.renderArgs(r.args)}</span>`,n+="</div>"}this.listEl.innerHTML=n,this.scrollLocked&&e.length>0&&(this.listEl.scrollTop=this.listEl.scrollHeight)}renderArgs(e){return e.map(t=>typeof t=="string"?h(t):typeof t=="number"||typeof t=="boolean"||t===null||t===void 0?`<span style="color:#b5cea8">${String(t)}</span>`:typeof t=="object"?R(t):h(String(t))).join(" ")}destroy(){this.renderRAF!==null&&cancelAnimationFrame(this.renderRAF),this.cleanups.forEach(e=>e()),this.cleanups.length=0,this.container.innerHTML=""}}class ge{constructor(e,t){this.tableBody=null,this.detailEl=null,this.selectedId=null,this.sortKey="duration",this.sortDir="desc",this.searchText="",this.renderRAF=null,this.needsRefresh=!1,this.cleanups=[],this.container=e,this.core=t,this.render(),this.bindEvents()}render(){this.container.innerHTML=`
      <div class="nc-toolbar">
        <input type="text" placeholder="Filter requests..." class="nc-network-search" />
        <button class="nc-toolbar-btn nc-network-clear">Clear</button>
      </div>
      <div style="flex:1;overflow:auto;display:flex;flex-direction:column">
        <div style="flex:1;overflow:auto">
          <table class="nc-network-table">
            <thead>
              <tr>
                <th data-nc-sort="method" style="width:60px">Method</th>
                <th data-nc-sort="url">URL</th>
                <th data-nc-sort="status" style="width:60px">Status</th>
                <th data-nc-sort="type" style="width:50px">Type</th>
                <th data-nc-sort="duration" style="width:80px">Time</th>
              </tr>
            </thead>
            <tbody class="nc-network-tbody"></tbody>
          </table>
        </div>
        <div class="nc-network-detail" style="display:none"></div>
      </div>
    `,this.tableBody=this.container.querySelector(".nc-network-tbody"),this.detailEl=this.container.querySelector(".nc-network-detail"),this.refreshTable()}bindEvents(){this.container.querySelectorAll("[data-nc-sort]").forEach(i=>{i.addEventListener("click",()=>{const a=i.dataset.ncSort;this.sortKey===a?this.sortDir=this.sortDir==="asc"?"desc":"asc":(this.sortKey=a,this.sortDir="asc"),this.refreshTable()})});const e=this.container.querySelector(".nc-network-search");let t;e.addEventListener("input",()=>{clearTimeout(t),t=setTimeout(()=>{this.searchText=e.value,this.refreshTable()},150)}),this.container.querySelector(".nc-network-clear").addEventListener("click",()=>{this.core.clear(),this.selectedId=null,this.detailEl&&(this.detailEl.style.display="none")}),this.container.addEventListener("click",i=>{const a=i.target.closest("[data-nc-req-id]");a&&(this.selectedId=Number(a.dataset.ncReqId),this.showDetail())});const n=this.core.on("request",()=>this.scheduleRefresh()),s=this.core.on("update",()=>{this.scheduleRefresh(),this.selectedId&&this.isRenderable()&&this.showDetail()}),r=this.core.on("clear",()=>this.scheduleRefresh());this.cleanups.push(n,s,r)}scheduleRefresh(){if(!this.isRenderable()){this.needsRefresh=!0;return}this.renderRAF===null&&(this.renderRAF=requestAnimationFrame(()=>{this.renderRAF=null,this.refreshTable()}))}refresh(){this.renderRAF!==null&&(cancelAnimationFrame(this.renderRAF),this.renderRAF=null),this.needsRefresh=!1,this.refreshTable(),this.selectedId&&this.showDetail()}isRenderable(){return this.container.classList.contains("nc-tab-pane-active")&&this.container.closest(".nc-panel-visible")!==null}refreshTable(){if(!this.tableBody)return;let e=this.core.getEntries().slice();if(this.searchText){const n=this.searchText.toLowerCase();e=e.filter(s=>s.url.toLowerCase().includes(n))}e.sort((n,s)=>{let r="",i="";switch(this.sortKey){case"url":r=n.url,i=s.url;break;case"method":r=n.method,i=s.method;break;case"status":r=n.status,i=s.status;break;case"type":r=n.type,i=s.type;break;case"duration":r=n.duration,i=s.duration;break}if(typeof r=="string"){const a=r.localeCompare(i);return this.sortDir==="asc"?a:-a}return this.sortDir==="asc"?r-i:i-r});let t="";for(const n of e){const s=n.pending?"nc-status-pending":n.status>=400?"nc-status-err":"nc-status-ok",r=n.pending?"⏳":String(n.status),i=n.url.length>80?n.url.slice(0,80)+"…":n.url,a=n.messages&&n.messages.length>0?` (${n.messages.length})`:"";t+=`<tr data-nc-req-id="${n.id}">`,t+=`<td>${h(n.method)}</td>`,t+=`<td title="${h(n.url)}">${h(i)}</td>`,t+=`<td class="${s}">${r}</td>`,t+=`<td>${n.type}${a}</td>`,t+=`<td>${n.pending?n.type==="sse"||n.type==="websocket"?"●":"-":I(n.duration)}</td>`,t+="</tr>"}this.tableBody.innerHTML=t}showDetail(){if(!this.detailEl||!this.selectedId)return;const e=this.core.getEntries().find(s=>s.id===this.selectedId);if(!e){this.detailEl.style.display="none";return}this.detailEl.style.display="block";let t="";if(t+='<div class="nc-detail-section">',t+='<div class="nc-detail-title">General</div>',t+='<div class="nc-detail-body">',t+=`URL: ${h(e.url)}
`,t+=`Method: ${e.method}
`,t+=`Status: ${e.status} ${h(e.statusText)}
`,t+=`Type: ${e.type}
`,t+=`Duration: ${e.pending?"pending...":I(e.duration)}
`,e.messages&&(t+=`Messages: ${e.messages.length}
`),e.error&&(t+=`Error: ${h(e.error)}
`),t+="</div></div>",e.messages&&e.messages.length>0){t+='<div class="nc-detail-section">',t+=`<div class="nc-detail-title">Messages (${e.messages.length})${e.pending?' · <span style="color:#3dc9b0">● Live</span>':""}</div>`,t+='<div class="nc-detail-body nc-messages-stream">';const s=e.messages.slice(-100);e.messages.length>100&&(t+=`<div class="nc-msg-row nc-msg-info">... ${e.messages.length-100} earlier messages hidden</div>`);for(const r of s){const i=r.direction==="out"?"nc-msg-out":"nc-msg-in",a=r.direction==="out"?"↑":"↓",l=r.size!=null?` · ${this.formatSize(r.size)}`:"",c=r.event?` [${h(r.event)}]`:"";t+=`<div class="nc-msg-row ${i}">`,t+=`<span class="nc-msg-arrow">${a}</span>`,t+=`<span class="nc-msg-time">${B(r.timestamp)}</span>`,t+=`<span class="nc-msg-event">${c}</span>`,t+=`<span class="nc-msg-data">${this.formatMsgData(r.data)}</span>`,t+=`<span class="nc-msg-size">${l}</span>`,t+="</div>"}t+="</div></div>"}t+=this.renderHeaders("Request Headers",e.requestHeaders),t+=this.renderHeaders("Response Headers",e.responseHeaders),e.requestBody&&(t+='<div class="nc-detail-section">',t+='<div class="nc-detail-title">Request Body</div>',t+=`<div class="nc-detail-body">${R(e.requestBody)}</div>`,t+="</div>"),e.responseBody&&(t+='<div class="nc-detail-section">',t+='<div class="nc-detail-title">Response Body</div>',t+=`<div class="nc-detail-body">${R(e.responseBody)}</div>`,t+="</div>"),this.detailEl.innerHTML=t;const n=this.detailEl.querySelector(".nc-messages-stream");n&&(n.scrollTop=n.scrollHeight)}formatMsgData(e){try{const t=JSON.parse(e);return R(t)}catch{return h(e)}}formatSize(e){return e<1024?`${e} B`:`${(e/1024).toFixed(1)} KB`}renderHeaders(e,t){const n=Object.keys(t);if(n.length===0)return"";let s='<div class="nc-detail-section">';s+=`<div class="nc-detail-title">${e}</div>`,s+='<div class="nc-detail-body">';for(const r of n)s+=`${h(r)}: ${h(t[r])}
`;return s+="</div></div>",s}destroy(){this.renderRAF!==null&&cancelAnimationFrame(this.renderRAF),this.cleanups.forEach(e=>e()),this.cleanups.length=0,this.container.innerHTML=""}}class me{constructor(e,t){this.tableBody=null,this.searchText="",this.activeType="all",this.cleanups=[],this.currentEntries=[],this.container=e,this.core=t,this.render(),this.bindEvents()}render(){this.container.innerHTML=`
      <div class="nc-toolbar">
        <button class="nc-toolbar-btn nc-active" data-nc-stype="all">All</button>
        <button class="nc-toolbar-btn" data-nc-stype="localStorage">Local</button>
        <button class="nc-toolbar-btn" data-nc-stype="sessionStorage">Session</button>
        <button class="nc-toolbar-btn" data-nc-stype="cookie">Cookie</button>
        <input type="text" placeholder="Filter keys..." class="nc-storage-search" />
        <button class="nc-toolbar-btn nc-storage-add">+ Add</button>
        <button class="nc-toolbar-btn nc-storage-refresh">↻</button>
      </div>
      <div style="flex:1;overflow:auto">
        <table class="nc-storage-table">
          <thead>
            <tr>
              <th style="width:25%">Key</th>
              <th>Value</th>
              <th style="width:auto">Type</th>
              <th style="width:1%">Actions</th>
            </tr>
          </thead>
          <tbody class="nc-storage-tbody"></tbody>
        </table>
      </div>
    `,this.tableBody=this.container.querySelector(".nc-storage-tbody"),this.refreshTable()}bindEvents(){this.container.addEventListener("click",s=>{const r=s.target.closest("[data-nc-stype]");r&&(this.activeType=r.dataset.ncStype,this.container.querySelectorAll("[data-nc-stype]").forEach(i=>i.classList.remove("nc-active")),r.classList.add("nc-active"),this.refreshTable())});const e=this.container.querySelector(".nc-storage-search");let t;e.addEventListener("input",()=>{clearTimeout(t),t=setTimeout(()=>{this.searchText=e.value,this.refreshTable()},150)}),this.container.querySelector(".nc-storage-add").addEventListener("click",()=>{this.showAddDialog()}),this.container.querySelector(".nc-storage-refresh").addEventListener("click",()=>{this.refreshTable()}),this.container.addEventListener("click",s=>{const r=s.target;if(r.dataset.ncAction==="edit"){const a=r.dataset.ncKey,l=r.dataset.ncType;this.showEditDialog(l,a);return}if(r.dataset.ncAction==="delete"){const a=r.dataset.ncKey,l=r.dataset.ncType;this.core.removeItem(l,a),this.refreshTable();return}const i=r.closest("tr[data-nc-row]");if(i&&!r.closest(".nc-storage-actions")){const a=i.nextElementSibling;if(a&&a.classList.contains("nc-storage-detail"))i.classList.remove("nc-storage-expanded"),a.remove();else{this.tableBody?.querySelectorAll(".nc-storage-detail").forEach(d=>{d.previousElementSibling?.classList.remove("nc-storage-expanded"),d.remove()}),i.classList.add("nc-storage-expanded");const l=parseInt(i.dataset.ncIdx||"0",10),c=this.currentEntries[l]?.value||"",u=document.createElement("tr");u.className="nc-storage-detail",u.innerHTML=`<td colspan="4">${h(c)}</td>`,i.after(u)}}});const n=this.core.on("update",()=>this.refreshTable());this.cleanups.push(n)}refreshTable(){if(!this.tableBody)return;let e=this.core.getEntries(this.searchText||void 0);this.activeType!=="all"&&(e=e.filter(n=>n.type===this.activeType)),this.currentEntries=e;let t="";for(let n=0;n<e.length;n++){const s=e[n],r=s.value.length>60?s.value.slice(0,60)+"…":s.value;t+=`<tr data-nc-row data-nc-idx="${n}" style="cursor:pointer">`,t+=`<td>${h(s.key)}</td>`,t+=`<td>${h(r)}</td>`,t+=`<td class="nc-storage-type">${s.type}</td>`,t+='<td class="nc-storage-actions">',t+=`<button data-nc-action="edit" data-nc-key="${h(s.key)}" data-nc-type="${s.type}">Edit</button>`,t+=`<button class="nc-danger" data-nc-action="delete" data-nc-key="${h(s.key)}" data-nc-type="${s.type}">Del</button>`,t+="</td>",t+="</tr>"}e.length===0&&(t='<tr><td colspan="4" style="text-align:center;color:#666;padding:20px">No entries found</td></tr>'),this.tableBody.innerHTML=t}showAddDialog(){this.showModal("Add Entry",{type:this.activeType!=="all"?this.activeType:"localStorage",key:"",value:""},e=>{this.core.setItem(e.type,e.key,e.value),this.refreshTable()})}showEditDialog(e,t){const s=this.core.getEntries().find(r=>r.type===e&&r.key===t);s&&this.showModal("Edit Entry",{type:s.type,key:s.key,value:s.value},r=>{const i=r.type;i!==e||r.key!==t?this.core.setItem(i,r.key,r.value)&&this.core.removeItem(e,t):this.core.setItem(i,r.key,r.value),this.refreshTable()})}showModal(e,t,n){const s=document.createElement("div");s.className="nc-modal-overlay",s.innerHTML=`
      <div class="nc-modal">
        <h3>${h(e)}</h3>
        <label>Type</label>
        <select class="nc-modal-type">
          <option value="localStorage" ${t.type==="localStorage"?"selected":""}>localStorage</option>
          <option value="sessionStorage" ${t.type==="sessionStorage"?"selected":""}>sessionStorage</option>
          <option value="cookie" ${t.type==="cookie"?"selected":""}>cookie</option>
        </select>
        <label>Key</label>
        <input type="text" class="nc-modal-key" value="${h(t.key)}" />
        <label>Value</label>
        <textarea class="nc-modal-value" rows="3">${h(t.value)}</textarea>
        <div class="nc-modal-btns">
          <button class="nc-modal-cancel">Cancel</button>
          <button class="nc-primary nc-modal-save">Save</button>
        </div>
      </div>
    `,this.container.appendChild(s),s.querySelector(".nc-modal-cancel").addEventListener("click",()=>{s.remove()}),s.querySelector(".nc-modal-save").addEventListener("click",()=>{const r=s.querySelector(".nc-modal-type").value,i=s.querySelector(".nc-modal-key").value,a=s.querySelector(".nc-modal-value").value;i&&n({type:r,key:i,value:a}),s.remove()}),s.addEventListener("click",r=>{r.target===s&&s.remove()})}destroy(){this.cleanups.forEach(e=>e()),this.cleanups.length=0,this.container.innerHTML=""}}class be{constructor(e,t){this.container=e,this.core=t,this.render(),this.bindEvents()}render(){this.container.innerHTML=`
      <div class="nc-toolbar">
        <button class="nc-toolbar-btn nc-element-refresh">↻ Refresh</button>
      </div>
      <div class="nc-element-tree"></div>
    `,this.treeEl=this.container.querySelector(".nc-element-tree"),this.refreshTree()}refreshTree(){this.treeEl.innerHTML=this.core.renderTree(document.documentElement,6)}bindEvents(){this.container.querySelector(".nc-element-refresh").addEventListener("click",()=>{this.refreshTree()}),this.treeEl.addEventListener("click",e=>{const t=e.target.closest("[data-nc-toggle]");if(t){const n=t.dataset.ncToggle,s=this.treeEl.querySelector(`#${n}`);if(s){const r=s.style.display!=="none";s.style.display=r?"none":"block",t.textContent=r?"▶":"▼",t.classList.toggle("nc-expanded",!r)}}}),this.treeEl.addEventListener("mouseover",e=>{const t=e.target.closest("[data-nc-highlight]");if(t){const n=t.dataset.ncHighlight;this.core.highlight(n)}}),this.treeEl.addEventListener("mouseout",()=>{this.core.clearHighlight()})}destroy(){this.core.clearHighlight(),this.container.innerHTML=""}}function ve(){const o=navigator,e={userAgent:navigator.userAgent,platform:navigator.platform,language:navigator.language,screenWidth:screen.width,screenHeight:screen.height,viewportWidth:window.innerWidth,viewportHeight:window.innerHeight,devicePixelRatio:window.devicePixelRatio};return o.deviceMemory&&(e.deviceMemory=o.deviceMemory),o.hardwareConcurrency&&(e.hardwareConcurrency=o.hardwareConcurrency),o.connection&&(e.connectionType=o.connection.effectiveType||o.connection.type),e.performance=ye(),e}function ye(){if(typeof performance>"u")return;const o={};try{const t=performance.getEntriesByType("navigation");if(t.length>0){const n=t[0];n.loadEventEnd>0&&(o.pageLoadTime=Math.round(n.loadEventEnd-n.startTime)),n.domContentLoadedEventEnd>0&&(o.domContentLoaded=Math.round(n.domContentLoadedEventEnd-n.startTime))}}catch{}try{const t=performance.getEntriesByType("paint");for(const n of t)n.name==="first-paint"&&(o.firstPaint=Math.round(n.startTime)),n.name==="first-contentful-paint"&&(o.firstContentfulPaint=Math.round(n.startTime))}catch{}const e=performance;return e.memory&&(o.usedJSHeapSize=e.memory.usedJSHeapSize,o.totalJSHeapSize=e.memory.totalJSHeapSize),o}class xe{constructor(e){this.container=e,this.render()}render(){this.container.innerHTML=`
      <div class="nc-toolbar">
        <button class="nc-toolbar-btn nc-system-refresh">↻ Refresh</button>
      </div>
      <div class="nc-system-list"></div>
    `,this.container.querySelector(".nc-system-refresh").addEventListener("click",()=>{this.refreshInfo()}),this.refreshInfo()}refreshInfo(){const e=ve(),t=this.container.querySelector(".nc-system-list"),n=[["User Agent",e.userAgent],["Platform",e.platform],["Language",e.language],["Screen",`${e.screenWidth} × ${e.screenHeight}`],["Viewport",`${e.viewportWidth} × ${e.viewportHeight}`],["Device Pixel Ratio",String(e.devicePixelRatio)]];if(e.deviceMemory!==void 0&&n.push(["Device Memory",`${e.deviceMemory} GB`]),e.hardwareConcurrency!==void 0&&n.push(["CPU Cores",String(e.hardwareConcurrency)]),e.connectionType&&n.push(["Network Type",e.connectionType]),e.performance){const r=e.performance;r.pageLoadTime!==void 0&&n.push(["Page Load",`${r.pageLoadTime}ms`]),r.domContentLoaded!==void 0&&n.push(["DOM Content Loaded",`${r.domContentLoaded}ms`]),r.firstPaint!==void 0&&n.push(["First Paint",`${r.firstPaint}ms`]),r.firstContentfulPaint!==void 0&&n.push(["First Contentful Paint",`${r.firstContentfulPaint}ms`]),r.usedJSHeapSize!==void 0&&n.push(["JS Heap Used",`${(r.usedJSHeapSize/1048576).toFixed(1)} MB`]),r.totalJSHeapSize!==void 0&&n.push(["JS Heap Total",`${(r.totalJSHeapSize/1048576).toFixed(1)} MB`])}let s="";for(const[r,i]of n)s+='<div class="nc-system-row">',s+=`<div class="nc-system-key">${h(r)}</div>`,s+=`<div class="nc-system-val">${h(i)}</div>`,s+="</div>";t.innerHTML=s}destroy(){this.container.innerHTML=""}}class we{constructor(e,t){this.historyIndex=-1,this.currentInput="",this.cleanups=[],this.container=e,this.core=t,this.render(),this.bindEvents()}render(){this.container.innerHTML=`
      <div class="nc-toolbar">
        <button class="nc-toolbar-btn nc-repl-clear">Clear</button>
      </div>
      <div class="nc-repl-output"></div>
      <div class="nc-repl-input-wrap">
        <span class="nc-repl-prompt">&gt;</span>
        <textarea class="nc-repl-input" rows="1" placeholder="Enter JavaScript..." spellcheck="false" autocomplete="off" autocorrect="off" autocapitalize="off"></textarea>
        <button class="nc-repl-run">Run</button>
      </div>
    `,this.outputEl=this.container.querySelector(".nc-repl-output"),this.inputEl=this.container.querySelector(".nc-repl-input");for(const e of this.core.getEntries())this.appendEntry(e)}bindEvents(){this.container.querySelector(".nc-repl-run").addEventListener("click",()=>{this.executeInput()}),this.container.querySelector(".nc-repl-clear").addEventListener("click",()=>{this.core.clear()}),this.inputEl.addEventListener("keydown",n=>{n.key==="Enter"&&!n.shiftKey?(n.preventDefault(),this.executeInput()):n.key==="ArrowUp"&&this.inputEl.selectionStart===0?(n.preventDefault(),this.navigateHistory(-1)):n.key==="ArrowDown"&&(n.preventDefault(),this.navigateHistory(1))}),this.inputEl.addEventListener("input",()=>{this.autoResize()});const e=this.core.on("entry",n=>{this.appendEntry(n)}),t=this.core.on("clear",()=>{this.outputEl.innerHTML=""});this.cleanups.push(e,t)}executeInput(){const e=this.inputEl.value.trim();e&&(this.historyIndex=-1,this.currentInput="",this.inputEl.value="",this.autoResize(),this.core.execute(e))}navigateHistory(e){const t=this.core.getHistory();if(t.length===0)return;this.historyIndex===-1&&(this.currentInput=this.inputEl.value);const n=this.historyIndex+e;if(e<0){const s=this.historyIndex===-1?t.length-1:Math.max(0,n);this.historyIndex=s,this.inputEl.value=t[t.length-1-this.historyIndex]||""}else this.historyIndex<=0?(this.historyIndex=-1,this.inputEl.value=this.currentInput):(this.historyIndex=n,this.inputEl.value=t[t.length-1-this.historyIndex]||"");this.autoResize()}appendEntry(e){const t=document.createElement("div");t.className=`nc-repl-row nc-repl-${e.type}`;const n=`<span class="nc-log-time">${B(e.timestamp)}</span>`;if(e.type==="input")t.innerHTML=`${n}<span class="nc-repl-prompt">&gt;</span><span class="nc-repl-code">${h(e.content)}</span>`;else if(e.type==="error")t.innerHTML=`${n}<span class="nc-repl-result nc-repl-err">${h(e.content)}</span>`;else{let s;try{const r=JSON.parse(e.content);s=R(r)}catch{s=h(e.content)}t.innerHTML=`${n}<span class="nc-repl-result">${s}</span>`}this.outputEl.appendChild(t),this.outputEl.scrollTop=this.outputEl.scrollHeight}autoResize(){this.inputEl.style.height="auto",this.inputEl.style.height=`${Math.min(this.inputEl.scrollHeight,120)}px`}destroy(){this.cleanups.forEach(e=>e()),this.cleanups.length=0,this.container.innerHTML=""}}const ke=`
:host {
  --nc-bg: #1e1e1e;
  --nc-bg-secondary: #252526;
  --nc-bg-hover: #2a2d2e;
  --nc-bg-active: #37373d;
  --nc-border: #3c3c3c;
  --nc-text: #cccccc;
  --nc-text-secondary: #999999;
  --nc-text-muted: #666666;
  --nc-accent: #0078d4;
  --nc-accent-hover: #1a8cff;
  --nc-log: #d4d4d4;
  --nc-info: #3dc9b0;
  --nc-warn: #cca700;
  --nc-error: #f14c4c;
  --nc-debug: #9cdcfe;
  --nc-font: 'SF Mono', 'Menlo', 'Monaco', 'Consolas', monospace;
  --nc-font-size: 12px;
  --nc-radius: 4px;
  --nc-panel-height: 40vh;
  --nc-btn-size: 48px;
  --nc-shadow: 0 2px 8px rgba(0,0,0,0.4);
  --nc-modal-overlay: rgba(0,0,0,0.5);
  --nc-scrollbar-hover: #555;

  font-family: var(--nc-font);
  font-size: var(--nc-font-size);
  color: var(--nc-text);
  line-height: 1.5;
}

/* Light Theme */
:host(.nc-theme-light) {
  --nc-bg: #ffffff;
  --nc-bg-secondary: #f5f5f5;
  --nc-bg-hover: #e8e8e8;
  --nc-bg-active: #dcdcdc;
  --nc-border: #d4d4d4;
  --nc-text: #1e1e1e;
  --nc-text-secondary: #616161;
  --nc-text-muted: #9e9e9e;
  --nc-accent: #0066cc;
  --nc-accent-hover: #0055aa;
  --nc-log: #333333;
  --nc-info: #098658;
  --nc-warn: #9d6e00;
  --nc-error: #cd3131;
  --nc-debug: #0451a5;
  --nc-shadow: 0 2px 12px rgba(0,0,0,0.15);
  --nc-modal-overlay: rgba(0,0,0,0.3);
  --nc-scrollbar-hover: #aaa;
}

* {
  margin: 0;
  padding: 0;
  box-sizing: border-box;
}

/* Float Button */
.nc-float-btn {
  position: fixed;
  z-index: 2147483647;
  width: var(--nc-btn-size);
  height: var(--nc-btn-size);
  border-radius: 50%;
  background: var(--nc-accent);
  color: #fff;
  border: none;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 16px;
  font-weight: bold;
  font-family: var(--nc-font);
  box-shadow: var(--nc-shadow);
  touch-action: none;
  user-select: none;
  -webkit-user-select: none;
  transition: background 0.2s;
}
.nc-float-btn:active {
  background: var(--nc-accent-hover);
}

/* Panel Container */
.nc-backdrop {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  z-index: 2147483645;
  display: none;
  background: transparent;
}
.nc-backdrop.nc-backdrop-visible {
  display: block;
}
.nc-panel {
  position: fixed;
  bottom: 0;
  left: 0;
  right: 0;
  height: var(--nc-panel-height);
  z-index: 2147483646;
  background: var(--nc-bg);
  border-top: 1px solid var(--nc-border);
  display: flex;
  flex-direction: column;
  transform: translateY(100%);
  transition: transform 0.25s ease;
}
.nc-panel.nc-panel-visible {
  transform: translateY(0);
}

/* Resize Handle */
.nc-resize-handle {
  height: 6px;
  cursor: ns-resize;
  background: var(--nc-bg-secondary);
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}
.nc-resize-handle::after {
  content: '';
  width: 32px;
  height: 3px;
  background: var(--nc-border);
  border-radius: 2px;
}

/* Tab Bar */
.nc-tab-bar {
  display: flex;
  flex-direction: row;
  background: var(--nc-bg-secondary);
  border-bottom: 1px solid var(--nc-border);
  flex-shrink: 0;
  align-items: stretch;
  position: relative;
}
.nc-tab-bar::after {
  content: '';
  position: absolute;
  top: 0;
  right: 0;
  bottom: 0;
  width: 18px;
  pointer-events: none;
  background: linear-gradient(to right, rgba(37,37,38,0), var(--nc-bg-secondary));
}
.nc-tabs-scroll {
  display: flex;
  flex: 1;
  overflow-x: auto;
  -webkit-overflow-scrolling: touch;
  order: 1;
}
.nc-tab {
  padding: 8px 14px;
  cursor: pointer;
  color: var(--nc-text-secondary);
  border-bottom: 2px solid transparent;
  white-space: nowrap;
  font-size: 12px;
  font-family: var(--nc-font);
  transition: color 0.15s, border-color 0.15s;
  user-select: none;
  -webkit-user-select: none;
  flex-shrink: 0;
}
.nc-close-btn {
  width: 44px;
  min-width: 44px;
  min-height: 36px;
  padding: 0;
  cursor: pointer;
  color: var(--nc-text);
  font-size: 16px;
  font-family: var(--nc-font);
  background: var(--nc-bg-secondary);
  border: none;
  border-right: 1px solid var(--nc-border);
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  line-height: 1;
  order: 0;
}
.nc-close-btn:hover {
  color: var(--nc-error);
}
.nc-tab:hover {
  color: var(--nc-text);
}
.nc-tab.nc-tab-active {
  color: var(--nc-accent);
  border-bottom-color: var(--nc-accent);
}

/* Tab Content */
.nc-tab-content {
  flex: 1;
  overflow: hidden;
  position: relative;
}
.nc-tab-pane {
  position: absolute;
  top: 0; left: 0; right: 0; bottom: 0;
  overflow: auto;
  display: none;
  flex-direction: column;
  -webkit-overflow-scrolling: touch;
}
.nc-tab-pane.nc-tab-pane-active {
  display: flex;
}

/* Toolbar */
.nc-toolbar {
  display: flex;
  align-items: center;
  gap: 4px;
  padding: 4px 8px;
  background: var(--nc-bg-secondary);
  border-bottom: 1px solid var(--nc-border);
  flex-shrink: 0;
}
.nc-toolbar-group {
  display: flex;
  align-items: center;
  gap: 4px;
  min-width: 0;
  flex-shrink: 0;
}
.nc-console-toolbar {
  flex-wrap: wrap;
  row-gap: 4px;
}
.nc-console-filter-group {
  flex-wrap: wrap;
}
.nc-console-action-group {
  margin-left: auto;
}
.nc-toolbar input[type="text"] {
  flex: 1;
  background: var(--nc-bg);
  border: 1px solid var(--nc-border);
  color: var(--nc-text);
  padding: 3px 8px;
  border-radius: var(--nc-radius);
  font-size: 11px;
  font-family: var(--nc-font);
  outline: none;
  min-width: 0;
}
.nc-toolbar input[type="text"]:focus {
  border-color: var(--nc-accent);
}
.nc-console-toolbar input.nc-console-search {
  flex: 1 1 180px;
  min-width: 140px;
}
.nc-toolbar-btn {
  padding: 3px 8px;
  background: var(--nc-bg);
  border: 1px solid var(--nc-border);
  color: var(--nc-text-secondary);
  cursor: pointer;
  border-radius: var(--nc-radius);
  font-size: 11px;
  font-family: var(--nc-font);
  white-space: nowrap;
  transition: background 0.15s;
}
.nc-toolbar-btn:hover {
  background: var(--nc-bg-hover);
  color: var(--nc-text);
}
.nc-toolbar-btn.nc-active {
  background: var(--nc-accent);
  color: #fff;
  border-color: var(--nc-accent);
}

/* Console Panel */
.nc-console-list {
  flex: 1;
  overflow-y: auto;
  overflow-x: hidden;
  -webkit-overflow-scrolling: touch;
}
.nc-log-entry {
  padding: 4px 8px;
  border-bottom: 1px solid var(--nc-border);
  font-family: var(--nc-font);
  font-size: var(--nc-font-size);
  word-break: break-all;
  white-space: pre-wrap;
  display: flex;
  align-items: flex-start;
  gap: 8px;
  line-height: 1.4;
}
.nc-log-entry:hover {
  background: var(--nc-bg-hover);
}
.nc-log-time {
  color: var(--nc-text-muted);
  flex-shrink: 0;
  font-size: 10px;
  line-height: 1.4;
  padding-top: 1px;
}
.nc-log-body {
  flex: 1;
  min-width: 0;
  overflow-wrap: break-word;
}
.nc-log-level-log .nc-log-body { color: var(--nc-log); }
.nc-log-level-info .nc-log-body { color: var(--nc-info); }
.nc-log-level-warn .nc-log-body { color: var(--nc-warn); }
.nc-log-level-error .nc-log-body { color: var(--nc-error); }
.nc-log-level-debug .nc-log-body { color: var(--nc-debug); }
.nc-log-level-warn { background: rgba(204, 167, 0, 0.08); }
.nc-log-level-error { background: rgba(241, 76, 76, 0.08); }
.nc-log-streaming {
  border-left: 2px solid var(--nc-accent);
}

/* Network Panel */
.nc-network-table {
  width: 100%;
  border-collapse: collapse;
  font-size: 11px;
  table-layout: fixed;
}
.nc-network-table th {
  position: sticky;
  top: 0;
  background: var(--nc-bg-secondary);
  text-align: left;
  padding: 4px 8px;
  border-bottom: 1px solid var(--nc-border);
  color: var(--nc-text-secondary);
  font-weight: normal;
  cursor: pointer;
  user-select: none;
  -webkit-user-select: none;
}
.nc-network-table th:hover {
  color: var(--nc-text);
}
.nc-network-table td {
  padding: 4px 8px;
  border-bottom: 1px solid var(--nc-border);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.nc-network-table tr:hover td {
  background: var(--nc-bg-hover);
}
.nc-network-table .nc-status-ok { color: var(--nc-info); }
.nc-network-table .nc-status-err { color: var(--nc-error); }
.nc-network-table .nc-status-pending { color: var(--nc-warn); }

.nc-network-detail {
  padding: 8px;
  border-top: 1px solid var(--nc-border);
  background: var(--nc-bg-secondary);
  overflow: auto;
  max-height: 50%;
}
.nc-detail-section {
  margin-bottom: 8px;
}
.nc-detail-title {
  color: var(--nc-text-secondary);
  font-weight: bold;
  margin-bottom: 4px;
  cursor: pointer;
  user-select: none;
  -webkit-user-select: none;
}
.nc-detail-body {
  padding-left: 8px;
  white-space: pre-wrap;
  word-break: break-all;
}

/* Messages Stream (SSE/WebSocket) */
.nc-messages-stream {
  max-height: 200px;
  overflow-y: auto;
  padding: 0 !important;
  white-space: normal !important;
}
.nc-msg-row {
  display: flex;
  align-items: flex-start;
  gap: 6px;
  padding: 3px 8px;
  border-bottom: 1px solid var(--nc-border);
  font-size: 11px;
  line-height: 1.4;
}
.nc-msg-row:hover {
  background: var(--nc-bg-hover);
}
.nc-msg-out {
  color: #e07b39;
}
.nc-msg-in {
  color: #3dc9b0;
}
.nc-msg-info {
  color: var(--nc-text-secondary);
  font-style: italic;
  justify-content: center;
}
.nc-msg-arrow {
  flex-shrink: 0;
  font-weight: bold;
  width: 12px;
}
.nc-msg-time {
  flex-shrink: 0;
  color: var(--nc-text-secondary);
  font-size: 10px;
  min-width: 70px;
}
.nc-msg-event {
  flex-shrink: 0;
  color: #a78bfa;
  font-size: 10px;
}
.nc-msg-data {
  flex: 1;
  word-break: break-all;
  white-space: pre-wrap;
}
.nc-msg-size {
  flex-shrink: 0;
  color: var(--nc-text-secondary);
  font-size: 10px;
}

/* Storage Panel */
.nc-storage-table {
  width: 100%;
  border-collapse: collapse;
  font-size: 11px;
}
.nc-storage-table th {
  position: sticky;
  top: 0;
  background: var(--nc-bg-secondary);
  text-align: left;
  padding: 4px 8px;
  border-bottom: 1px solid var(--nc-border);
  color: var(--nc-text-secondary);
  font-weight: normal;
}
.nc-storage-table td {
  padding: 4px 8px;
  border-bottom: 1px solid var(--nc-border);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.nc-storage-table td.nc-storage-type {
  white-space: nowrap;
  overflow: visible;
}
.nc-storage-table td:last-child {
  overflow: visible;
  white-space: nowrap;
  width: 1%;
}
.nc-storage-table tr:hover td {
  background: var(--nc-bg-hover);
}
.nc-storage-table tr:hover td:last-child {
  background: transparent;
}
.nc-storage-table tr.nc-storage-expanded td {
  border-bottom: none;
}
.nc-storage-detail {
  background: var(--nc-bg-secondary);
  border-bottom: 1px solid var(--nc-border);
}
.nc-storage-detail td {
  padding: 8px;
  white-space: pre-wrap;
  word-break: break-all;
  max-width: none;
  overflow: visible;
  color: var(--nc-text);
  font-size: 11px;
  line-height: 1.5;
}
.nc-storage-actions {
  display: flex;
  gap: 4px;
}
.nc-storage-actions button {
  padding: 1px 6px;
  background: var(--nc-bg);
  border: 1px solid var(--nc-border);
  color: var(--nc-text-secondary);
  cursor: pointer;
  border-radius: 2px;
  font-size: 10px;
  font-family: var(--nc-font);
  position: relative;
  z-index: 1;
}
.nc-storage-actions button:hover {
  background: var(--nc-bg-hover);
  color: var(--nc-text);
}
.nc-storage-actions button.nc-danger:hover {
  color: var(--nc-error);
  border-color: var(--nc-error);
}

/* Element Panel */
.nc-element-tree {
  padding: 8px;
  font-size: 12px;
  overflow: auto;
  height: 100%;
}
.nc-dom-node {
  line-height: 1.6;
  cursor: default;
}
.nc-dom-tag { color: #569cd6; }
.nc-dom-attr { color: #9cdcfe; }
.nc-dom-attr-val { color: #ce9178; }
.nc-dom-text { color: #d4d4d4; }
:host(.nc-theme-light) .nc-dom-tag { color: #0000ff; }
:host(.nc-theme-light) .nc-dom-attr { color: #e50000; }
:host(.nc-theme-light) .nc-dom-attr-val { color: #a31515; }
:host(.nc-theme-light) .nc-dom-text { color: #333333; }
:host(.nc-theme-light) .nc-log-level-warn { background: rgba(157, 110, 0, 0.08); }
:host(.nc-theme-light) .nc-log-level-error { background: rgba(205, 49, 49, 0.08); }
:host(.nc-theme-light) .nc-msg-out { color: #c05717; }
:host(.nc-theme-light) .nc-msg-in { color: #098658; }
:host(.nc-theme-light) .nc-msg-event { color: #6f42c1; }
.nc-dom-toggle {
  cursor: pointer;
  display: inline-block;
  width: 12px;
  font-size: 10px;
  transition: transform 0.15s;
}
.nc-dom-toggle.nc-expanded {
  transform: rotate(90deg);
}

/* System Panel */
.nc-system-list {
  padding: 8px;
}
.nc-system-row {
  display: flex;
  padding: 4px 0;
  border-bottom: 1px solid var(--nc-border);
}
.nc-system-key {
  width: 200px;
  flex-shrink: 0;
  color: var(--nc-text-secondary);
}
.nc-system-val {
  flex: 1;
  word-break: break-all;
  min-width: 0;
}

@media (max-width: 480px) {
  .nc-toolbar {
    padding: 4px 6px;
  }
  .nc-toolbar-btn {
    padding-left: 7px;
    padding-right: 7px;
  }
  .nc-console-action-group {
    margin-left: 0;
  }
  .nc-tabs-scroll {
    padding-right: 12px;
  }
  .nc-system-row {
    gap: 8px;
  }
  .nc-system-key {
    width: 38%;
    min-width: 96px;
    max-width: 150px;
  }
}

/* Modal/Dialog for storage edit */
.nc-modal-overlay {
  position: absolute;
  top: 0; left: 0; right: 0; bottom: 0;
  background: var(--nc-modal-overlay);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 10;
}
.nc-modal {
  background: var(--nc-bg);
  border: 1px solid var(--nc-border);
  border-radius: var(--nc-radius);
  padding: 16px;
  min-width: 280px;
  max-width: 90%;
}
.nc-modal h3 {
  color: var(--nc-text);
  font-size: 13px;
  margin-bottom: 12px;
}
.nc-modal label {
  display: block;
  color: var(--nc-text-secondary);
  font-size: 11px;
  margin-bottom: 2px;
}
.nc-modal input, .nc-modal select, .nc-modal textarea {
  width: 100%;
  background: var(--nc-bg-secondary);
  border: 1px solid var(--nc-border);
  color: var(--nc-text);
  padding: 4px 8px;
  border-radius: var(--nc-radius);
  font-size: 12px;
  font-family: var(--nc-font);
  margin-bottom: 8px;
  outline: none;
}
.nc-modal input:focus, .nc-modal textarea:focus {
  border-color: var(--nc-accent);
}
.nc-modal-btns {
  display: flex;
  justify-content: flex-end;
  gap: 8px;
  margin-top: 8px;
}
.nc-modal-btns button {
  padding: 4px 12px;
  border: 1px solid var(--nc-border);
  background: var(--nc-bg-secondary);
  color: var(--nc-text);
  cursor: pointer;
  border-radius: var(--nc-radius);
  font-size: 12px;
  font-family: var(--nc-font);
}
.nc-modal-btns button.nc-primary {
  background: var(--nc-accent);
  border-color: var(--nc-accent);
  color: #fff;
}

/* Scrollbar */
::-webkit-scrollbar {
  width: 6px;
  height: 6px;
}
::-webkit-scrollbar-track {
  background: transparent;
}
::-webkit-scrollbar-thumb {
  background: var(--nc-border);
  border-radius: 3px;
}
::-webkit-scrollbar-thumb:hover {
  background: var(--nc-scrollbar-hover);
}

/* REPL Panel */
.nc-repl-output {
  flex: 1;
  overflow-y: auto;
  overflow-x: hidden;
  -webkit-overflow-scrolling: touch;
  padding: 4px 0;
}
.nc-repl-row {
  padding: 3px 8px;
  border-bottom: 1px solid var(--nc-border);
  font-family: var(--nc-font);
  font-size: var(--nc-font-size);
  word-break: break-all;
  white-space: pre-wrap;
  display: flex;
  align-items: flex-start;
  gap: 6px;
  line-height: 1.4;
}
.nc-repl-row:hover {
  background: var(--nc-bg-hover);
}
.nc-repl-input-wrap {
  display: flex;
  align-items: flex-start;
  gap: 6px;
  padding: 6px 8px;
  border-top: 1px solid var(--nc-border);
  background: var(--nc-bg-secondary);
  flex-shrink: 0;
}
.nc-repl-prompt {
  color: var(--nc-accent);
  font-weight: bold;
  font-family: var(--nc-font);
  font-size: var(--nc-font-size);
  line-height: 1.6;
  flex-shrink: 0;
  user-select: none;
  -webkit-user-select: none;
}
.nc-repl-input {
  flex: 1;
  background: var(--nc-bg);
  border: 1px solid var(--nc-border);
  color: var(--nc-text);
  padding: 4px 8px;
  border-radius: var(--nc-radius);
  font-size: var(--nc-font-size);
  font-family: var(--nc-font);
  outline: none;
  resize: none;
  line-height: 1.4;
  min-height: 24px;
  max-height: 120px;
  overflow-y: auto;
}
.nc-repl-input:focus {
  border-color: var(--nc-accent);
}
.nc-repl-run {
  padding: 4px 12px;
  background: var(--nc-accent);
  border: none;
  color: #fff;
  cursor: pointer;
  border-radius: var(--nc-radius);
  font-size: 11px;
  font-family: var(--nc-font);
  font-weight: bold;
  flex-shrink: 0;
  line-height: 1.4;
}
.nc-repl-run:hover {
  background: var(--nc-accent-hover);
}
.nc-repl-code {
  color: var(--nc-text);
  flex: 1;
}
.nc-repl-result {
  color: var(--nc-info);
  flex: 1;
}
.nc-repl-err {
  color: var(--nc-error);
}
.nc-repl-input .nc-repl-row.nc-repl-input {
  color: var(--nc-text-secondary);
}
`,U=[{key:"console",label:"Console"},{key:"network",label:"Network"},{key:"storage",label:"Storage"},{key:"element",label:"Element"},{key:"system",label:"System"},{key:"repl",label:"REPL"}];class Ee{constructor(e={}){this.visible=!1,this.mounted=!1,this.destroyed=!1,this.cleanups=[],this.plugins=[],this.pluginTabs=[],this.pluginPanelsRendered=new Set,this.initialized=!1,this.config=e,this.activeTab=e.defaultTab||"console",this.host=document.createElement("div"),this.host.id="nextconsole-host",this.shadow=this.host.attachShadow({mode:"closed"}),this.consoleCore=new Y(e.console),this.networkCore=new re(e.network),this.storageCore=new ie(e.storage),this.elementCore=new ce,this.replCore=new de}init(){const e=()=>{if(this.destroyed||this.mounted)return;(this.config.target||document.body).appendChild(this.host);const n=document.createElement("style");if(n.textContent=ke,this.shadow.appendChild(n),this.applyTheme(this.config.theme||"dark"),this.floatButton=new he(this.shadow,()=>this.toggle(),this.config.buttonPosition),this.createPanel(),this.consoleCore.init(),this.networkCore.init(),this.storageCore.init(),this.elementCore.init(),this.config.panelHeight){const s=C(this.config.panelHeight,.1,.9);this.panelEl.style.setProperty("--nc-panel-height",`${s*100}vh`)}this.initialized=!0,this.mounted=!0;for(const s of this.plugins)this.initPlugin(s);this.applyVisibility(),this.config.onReady?.()};document.body?e():(document.addEventListener("DOMContentLoaded",e,{once:!0}),this.cleanups.push(()=>document.removeEventListener("DOMContentLoaded",e)))}createPanel(){this.backdropEl=document.createElement("div"),this.backdropEl.className="nc-backdrop",this.backdropEl.addEventListener("click",()=>this.hide()),this.shadow.appendChild(this.backdropEl),this.panelEl=document.createElement("div"),this.panelEl.className="nc-panel";const e=document.createElement("div");e.className="nc-resize-handle",this.panelEl.appendChild(e),this.bindResize(e);const t=document.createElement("div");t.className="nc-tab-bar";const n=document.createElement("button");n.type="button",n.className="nc-close-btn",n.textContent="✕",n.title="Close",n.setAttribute("aria-label","Close NextConsole"),n.addEventListener("click",()=>this.hide()),t.appendChild(n);const s=document.createElement("div");s.className="nc-tabs-scroll";for(const r of U){const i=document.createElement("div");i.className=`nc-tab${r.key===this.activeTab?" nc-tab-active":""}`,i.textContent=r.label,i.dataset.ncTab=r.key,s.appendChild(i)}t.appendChild(s),this.panelEl.appendChild(t),this.tabContentEl=document.createElement("div"),this.tabContentEl.className="nc-tab-content";for(const r of U){const i=document.createElement("div");i.className=`nc-tab-pane${r.key===this.activeTab?" nc-tab-pane-active":""}`,i.dataset.ncPane=r.key,this.tabContentEl.appendChild(i)}this.panelEl.appendChild(this.tabContentEl),this.shadow.appendChild(this.panelEl),t.addEventListener("click",r=>{const i=r.target.closest("[data-nc-tab]");i&&this.switchTab(i.dataset.ncTab)}),this.activatePanel(this.activeTab)}switchTab(e){e!==this.activeTab&&(this.activeTab=e,this.shadow.querySelectorAll(".nc-tab").forEach(t=>{t.classList.toggle("nc-tab-active",t.dataset.ncTab===e)}),this.shadow.querySelectorAll(".nc-tab-pane").forEach(t=>{t.classList.toggle("nc-tab-pane-active",t.dataset.ncPane===e)}),this.activatePanel(e))}activatePanel(e){const t=this.shadow.querySelector(`[data-nc-pane="${e}"]`);if(t)switch(e){case"console":this.consolePanel?this.consolePanel.refresh():this.consolePanel=new fe(t,this.consoleCore);break;case"network":this.networkPanel?this.networkPanel.refresh():this.networkPanel=new ge(t,this.networkCore);break;case"storage":this.storagePanel?this.storagePanel.refreshTable():this.storagePanel=new me(t,this.storageCore);break;case"element":this.elementPanel||(this.elementPanel=new be(t,this.elementCore));break;case"system":this.systemPanel||(this.systemPanel=new xe(t));break;case"repl":this.replPanel||(this.replPanel=new we(t,this.replCore));break;default:if(e.startsWith("plugin-")&&!this.pluginPanelsRendered.has(e)){const n=e.slice(7),s=this.plugins.find(r=>r.name===n);s?.tab&&(s.tab.render(t,this.getPluginAPI()),this.pluginPanelsRendered.add(e))}break}}bindResize(e){let t=0,n=0,s=!1;const r=a=>{if(!s)return;const l=t-a,c=C(n+l,100,window.innerHeight-60);this.panelEl.style.height=`${c}px`},i=()=>{s=!1};e.addEventListener("mousedown",a=>{s=!0,t=a.clientY,n=this.panelEl.offsetHeight}),e.addEventListener("touchstart",a=>{s=!0,t=a.touches[0].clientY,n=this.panelEl.offsetHeight},{passive:!0}),this.cleanups.push(v(window,"mousemove",a=>r(a.clientY)),v(window,"mouseup",i),v(window,"touchmove",a=>r(a.touches[0].clientY)),v(window,"touchend",i))}show(){this.visible||(this.visible=!0,this.applyVisibility())}hide(){this.visible&&(this.visible=!1,this.applyVisibility())}applyVisibility(){this.mounted&&(this.backdropEl.classList.toggle("nc-backdrop-visible",this.visible),this.panelEl.classList.toggle("nc-panel-visible",this.visible),this.visible?(this.floatButton.hide(),this.activatePanel(this.activeTab)):this.floatButton.show())}toggle(){this.visible?this.hide():this.show()}isVisible(){return this.visible}getConsoleCore(){return this.consoleCore}getNetworkCore(){return this.networkCore}getStorageCore(){return this.storageCore}setTheme(e){this.applyTheme(e)}applyTheme(e){e==="light"?this.host.classList.add("nc-theme-light"):this.host.classList.remove("nc-theme-light")}use(e){this.plugins.some(t=>t.name===e.name)||(this.plugins.push(e),this.initialized&&this.initPlugin(e))}getPluginAPI(){return this.pluginAPI||(this.pluginAPI={consoleCore:this.consoleCore,networkCore:this.networkCore,storageCore:this.storageCore,addStyle:e=>{const t=document.createElement("style");t.textContent=e,this.shadow.appendChild(t)},log:(...e)=>{console.log("[NextConsole Plugin]",...e)},show:()=>this.show(),hide:()=>this.hide()}),this.pluginAPI}initPlugin(e){const t=this.getPluginAPI();if(e.tab){const n=`plugin-${e.name}`;this.pluginTabs.push({key:n,label:e.tab.label});const s=this.shadow.querySelector(".nc-tabs-scroll");if(s){const r=document.createElement("div");r.className="nc-tab",r.textContent=e.tab.label,r.dataset.ncTab=n,s.appendChild(r)}if(this.tabContentEl){const r=document.createElement("div");r.className="nc-tab-pane",r.dataset.ncPane=n,this.tabContentEl.appendChild(r)}}e.init?.(t)}destroyPlugin(e){const t=`plugin-${e.name}`;if(e.tab&&this.pluginPanelsRendered.has(t))try{e.tab.destroy?.()}catch(n){console.error("[NextConsole Plugin] tab destroy failed",e.name,n)}try{e.destroy?.()}catch(n){console.error("[NextConsole Plugin] destroy failed",e.name,n)}}destroy(){if(!this.destroyed){this.destroyed=!0,this.consolePanel?.destroy(),this.networkPanel?.destroy(),this.storagePanel?.destroy(),this.elementPanel?.destroy(),this.systemPanel?.destroy(),this.replPanel?.destroy(),this.floatButton?.destroy();for(const e of this.plugins)this.destroyPlugin(e);this.consoleCore.destroy(),this.networkCore.destroy(),this.storageCore.destroy(),this.elementCore.destroy(),this.replCore.destroy(),this.plugins.length=0,this.pluginTabs.length=0,this.pluginPanelsRendered.clear(),this.cleanups.forEach(e=>e()),this.cleanups.length=0,this.host.remove(),this.mounted=!1}}}const Se=`
.nc-source-list {
  flex: 1;
  overflow-y: auto;
  -webkit-overflow-scrolling: touch;
}
.nc-source-item {
  padding: 8px 12px;
  border-bottom: 1px solid var(--nc-border);
  cursor: pointer;
  transition: background 0.15s;
}
.nc-source-item:hover {
  background: var(--nc-bg-hover);
}
.nc-source-item-active {
  background: var(--nc-bg-active);
}
.nc-source-tag {
  display: inline-block;
  padding: 1px 6px;
  border-radius: 3px;
  font-size: 10px;
  font-weight: bold;
  margin-right: 6px;
  text-transform: uppercase;
}
.nc-source-tag-script { background: #2b5b84; color: #9cdcfe; }
.nc-source-tag-style { background: #5b3a84; color: #dbb6f2; }
.nc-source-tag-inline-script { background: #1e4a3a; color: #89d185; }
.nc-source-tag-inline-style { background: #4a3a1e; color: #d1b185; }
.nc-source-name {
  color: var(--nc-text);
  font-size: 12px;
  word-break: break-all;
}
.nc-source-meta {
  color: var(--nc-text-muted);
  font-size: 11px;
  margin-top: 2px;
}
.nc-source-detail {
  flex: 1;
  display: flex;
  flex-direction: column;
  overflow: hidden;
}
.nc-source-detail-header {
  padding: 6px 10px;
  background: var(--nc-bg-secondary);
  border-bottom: 1px solid var(--nc-border);
  display: flex;
  justify-content: space-between;
  align-items: center;
  flex-shrink: 0;
}
.nc-source-detail-title {
  font-size: 12px;
  color: var(--nc-text);
  word-break: break-all;
}
.nc-source-detail-back {
  padding: 2px 8px;
  background: var(--nc-bg);
  border: 1px solid var(--nc-border);
  color: var(--nc-text);
  cursor: pointer;
  border-radius: var(--nc-radius);
  font-size: 11px;
  flex-shrink: 0;
  margin-left: 8px;
}
.nc-source-detail-back:hover {
  background: var(--nc-bg-hover);
}
.nc-source-code {
  flex: 1;
  overflow: auto;
  -webkit-overflow-scrolling: touch;
  padding: 8px 0;
  margin: 0;
  background: var(--nc-bg);
  counter-reset: line;
}
.nc-source-line {
  display: flex;
  padding: 0 12px 0 0;
  min-height: 18px;
  line-height: 18px;
}
.nc-source-line:hover {
  background: var(--nc-bg-hover);
}
.nc-source-lineno {
  display: inline-block;
  width: 40px;
  text-align: right;
  padding-right: 12px;
  color: var(--nc-text-muted);
  user-select: none;
  -webkit-user-select: none;
  flex-shrink: 0;
  font-size: 11px;
}
.nc-source-linetext {
  white-space: pre;
  color: var(--nc-text);
  flex: 1;
  overflow-x: auto;
}
.nc-source-empty {
  padding: 20px;
  text-align: center;
  color: var(--nc-text-muted);
}
.nc-source-view {
  display: flex;
  flex-direction: column;
  height: 100%;
}
`;function Te(o){return o<1024?`${o} B`:o<1024*1024?`${(o/1024).toFixed(1)} KB`:`${(o/(1024*1024)).toFixed(1)} MB`}function $e(){const o=[];return document.querySelectorAll("script[src]").forEach(e=>{const t=e.src;o.push({type:"script",url:t})}),document.querySelectorAll("script:not([src])").forEach(e=>{const t=e.textContent||"";t.trim()&&o.push({type:"inline-script",content:t,size:t.length})}),document.querySelectorAll('link[rel="stylesheet"]').forEach(e=>{const t=e.href;o.push({type:"style",url:t})}),document.querySelectorAll("style").forEach(e=>{const t=e.textContent||"";t.trim()&&!e.closest("#nextconsole-host")&&o.push({type:"inline-style",content:t,size:t.length})}),o}function Le(o){if(o.url)try{const t=new URL(o.url);return t.pathname.split("/").pop()||t.pathname}catch{return o.url}const e=(o.content||"").trim().slice(0,60);return e+(e.length>=60?"...":"")}function Ce(){let o;function e(){const n=$e();if(n.length===0){o.innerHTML='<div class="nc-source-view"><div class="nc-source-empty">No sources found</div></div>';return}const s=n.map((r,i)=>{const a=`nc-source-tag-${r.type}`,l=r.type.replace("-"," "),c=h(Le(r)),u=r.url?h(r.url):`${Te(r.size||0)}`;return`<div class="nc-source-item" data-idx="${i}">
        <span class="nc-source-tag ${a}">${l}</span>
        <span class="nc-source-name">${c}</span>
        <div class="nc-source-meta">${u}</div>
      </div>`}).join("");o.innerHTML=`
      <div class="nc-source-view">
        <div class="nc-toolbar">
          <button class="nc-toolbar-btn nc-source-refresh">Refresh</button>
          <span style="color:var(--nc-text-muted);font-size:11px;margin-left:8px">${n.length} sources</span>
        </div>
        <div class="nc-source-list">${s}</div>
      </div>`,o.querySelector(".nc-source-refresh").addEventListener("click",e),o.querySelector(".nc-source-list").addEventListener("click",r=>{const i=r.target.closest(".nc-source-item");if(!i)return;const a=parseInt(i.dataset.idx,10);t(n[a])})}async function t(n){const s=n.url?h(n.url):h(n.type);o.innerHTML=`
      <div class="nc-source-view">
        <div class="nc-source-detail-header">
          <span class="nc-source-detail-title">${s}</span>
          <button class="nc-source-detail-back">← Back</button>
        </div>
        <div class="nc-source-code"><div class="nc-source-empty">Loading...</div></div>
      </div>`,o.querySelector(".nc-source-detail-back").addEventListener("click",e);let r=n.content||"";if(!r&&n.url)try{r=await(await fetch(n.url)).text()}catch(d){const f=o.querySelector(".nc-source-code");f.innerHTML=`<div class="nc-source-empty" style="color:var(--nc-error)">Failed to fetch: ${h(String(d))}</div>`;return}const i=r.split(`
`),a=o.querySelector(".nc-source-code"),l=5e3,c=Math.min(i.length,l);let u="";for(let d=0;d<c;d++)u+=`<div class="nc-source-line"><span class="nc-source-lineno">${d+1}</span><span class="nc-source-linetext">${h(i[d])}</span></div>`;i.length>l&&(u+=`<div class="nc-source-empty">... ${i.length-l} more lines truncated</div>`),a.innerHTML=u}return{name:"source",version:"1.0.0",tab:{label:"Source",render(n,s){o=n,s.addStyle(Se),e()},destroy(){o.innerHTML=""}}}}const Re=`
.nc-perf-view {
  display: flex;
  flex-direction: column;
  height: 100%;
}
.nc-perf-scroll {
  flex: 1;
  overflow-y: auto;
  -webkit-overflow-scrolling: touch;
  padding: 8px;
}
.nc-perf-section {
  margin-bottom: 12px;
}
.nc-perf-section-title {
  font-size: 12px;
  font-weight: bold;
  color: var(--nc-text);
  padding: 6px 0 4px;
  border-bottom: 1px solid var(--nc-border);
  margin-bottom: 6px;
}
.nc-perf-metrics {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(140px, 1fr));
  gap: 6px;
}
.nc-perf-card {
  background: var(--nc-bg-secondary);
  border: 1px solid var(--nc-border);
  border-radius: var(--nc-radius);
  padding: 8px 10px;
  border-left: 3px solid var(--nc-border);
}
.nc-perf-card-good { border-left-color: #3dc9b0; }
.nc-perf-card-needs-improvement { border-left-color: #cca700; }
.nc-perf-card-poor { border-left-color: #f14c4c; }
.nc-perf-card-name {
  font-size: 10px;
  color: var(--nc-text-muted);
  text-transform: uppercase;
  letter-spacing: 0.5px;
}
.nc-perf-card-value {
  font-size: 18px;
  font-weight: bold;
  color: var(--nc-text);
  margin: 2px 0;
}
.nc-perf-card-unit {
  font-size: 11px;
  color: var(--nc-text-secondary);
  font-weight: normal;
}
.nc-perf-bar-wrap {
  display: flex;
  align-items: center;
  padding: 3px 0;
  font-size: 11px;
  gap: 6px;
}
.nc-perf-bar-label {
  flex-shrink: 0;
  width: 100px;
  color: var(--nc-text-secondary);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.nc-perf-bar-track {
  flex: 1;
  height: 14px;
  background: var(--nc-bg-secondary);
  border-radius: 2px;
  overflow: hidden;
  position: relative;
}
.nc-perf-bar-fill {
  height: 100%;
  border-radius: 2px;
  min-width: 1px;
}
.nc-perf-bar-fill-script { background: #2b5b84; }
.nc-perf-bar-fill-css { background: #5b3a84; }
.nc-perf-bar-fill-img { background: #3a845b; }
.nc-perf-bar-fill-font { background: #845b3a; }
.nc-perf-bar-fill-other { background: #555; }
.nc-perf-bar-value {
  flex-shrink: 0;
  width: 60px;
  text-align: right;
  color: var(--nc-text-muted);
}
.nc-perf-table {
  width: 100%;
  border-collapse: collapse;
  font-size: 11px;
}
.nc-perf-table th {
  text-align: left;
  padding: 4px 8px;
  border-bottom: 1px solid var(--nc-border);
  color: var(--nc-text-muted);
  font-weight: normal;
  text-transform: uppercase;
  font-size: 10px;
  position: sticky;
  top: 0;
  background: var(--nc-bg);
}
.nc-perf-table td {
  padding: 3px 8px;
  border-bottom: 1px solid var(--nc-border);
  color: var(--nc-text);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  max-width: 200px;
}
.nc-perf-table tr:hover td {
  background: var(--nc-bg-hover);
}
.nc-perf-empty {
  text-align: center;
  color: var(--nc-text-muted);
  padding: 16px;
}
.nc-perf-mark-btn {
  padding: 2px 8px;
  background: var(--nc-bg);
  border: 1px solid var(--nc-border);
  color: var(--nc-text);
  cursor: pointer;
  border-radius: var(--nc-radius);
  font-size: 11px;
  margin-left: 6px;
}
.nc-perf-mark-btn:hover { background: var(--nc-bg-hover); }
`;function H(o){return o<1?`${(o*1e3).toFixed(0)} μs`:o<1e3?`${o.toFixed(1)} ms`:`${(o/1e3).toFixed(2)} s`}function q(o){return o<=0?"—":o<1024?`${o} B`:o<1024*1024?`${(o/1024).toFixed(1)} KB`:`${(o/(1024*1024)).toFixed(1)} MB`}function M(o,e){switch(o){case"FCP":return e<=1800?"good":e<=3e3?"needs-improvement":"poor";case"LCP":return e<=2500?"good":e<=4e3?"needs-improvement":"poor";case"FID":return e<=100?"good":e<=300?"needs-improvement":"poor";case"CLS":return e<=.1?"good":e<=.25?"needs-improvement":"poor";case"TTFB":return e<=800?"good":e<=1800?"needs-improvement":"poor";case"INP":return e<=200?"good":e<=500?"needs-improvement":"poor";default:return"good"}}function He(o){const e=o.name.split("?")[0].split(".").pop()?.toLowerCase()||"";return["js","mjs"].includes(e)||o.initiatorType==="script"?"script":["css"].includes(e)||o.initiatorType==="css"||o.initiatorType==="link"?"css":["png","jpg","jpeg","gif","webp","svg","ico","avif"].includes(e)||o.initiatorType==="img"?"img":["woff","woff2","ttf","otf","eot"].includes(e)?"font":"other"}function Me(o){try{const e=new URL(o),t=e.pathname.split("/").pop()||e.pathname;return t.length>40?t.slice(0,37)+"...":t}catch{return o.slice(0,40)}}function Pe(){const o=[],e=performance.getEntriesByType("navigation");if(e.length>0){const s=e[0],r=s.responseStart-s.requestStart;r>0&&o.push({name:"TTFB",value:r,unit:"ms",rating:M("TTFB",r)});const i=s.domContentLoadedEventEnd-s.startTime;i>0&&o.push({name:"DOM Ready",value:i,unit:"ms",rating:M("FCP",i)});const a=s.loadEventEnd-s.startTime;a>0&&o.push({name:"Load",value:a,unit:"ms",rating:M("LCP",a)});const l=s.domainLookupEnd-s.domainLookupStart;l>0&&o.push({name:"DNS",value:l,unit:"ms",rating:"good"});const c=s.connectEnd-s.connectStart;c>0&&o.push({name:"TCP",value:c,unit:"ms",rating:"good"})}const t=performance.getEntriesByType("paint");for(const s of t)s.name==="first-paint"&&o.push({name:"FP",value:s.startTime,unit:"ms",rating:M("FCP",s.startTime)}),s.name==="first-contentful-paint"&&o.push({name:"FCP",value:s.startTime,unit:"ms",rating:M("FCP",s.startTime)});const n=performance.memory;return n&&(o.push({name:"JS Heap",value:n.usedJSHeapSize/(1024*1024),unit:"MB",rating:n.usedJSHeapSize/n.jsHeapSizeLimit>.9?"poor":"good"}),o.push({name:"Heap Limit",value:n.jsHeapSizeLimit/(1024*1024),unit:"MB",rating:"good"})),o}function ze(){return performance.getEntriesByType("resource").map(o=>({name:o.name,type:He(o),duration:o.duration,size:o.transferSize||0,startTime:o.startTime})).sort((o,e)=>e.duration-o.duration)}function Ne(){try{return performance.getEntriesByType("longtask").map(o=>({startTime:o.startTime,duration:o.duration})).sort((o,e)=>e.duration-o.duration)}catch{return[]}}function Be(){let o,e=null,t=[],n=[];function s(){const r=Pe(),i=ze(),a=[...t,...Ne()],l=new Map;for(const p of a)l.set(p.startTime,p);const c=[...l.values()].sort((p,b)=>b.duration-p.duration),u=new Map;for(const p of i){const b=u.get(p.type)||{count:0,totalSize:0,totalDuration:0};b.count++,b.totalSize+=p.size,b.totalDuration+=p.duration,u.set(p.type,b)}i.length>0&&Math.max(...i.map(p=>p.duration),1);const d=r.length>0?r.map(p=>`
        <div class="nc-perf-card nc-perf-card-${p.rating}">
          <div class="nc-perf-card-name">${h(p.name)}</div>
          <div class="nc-perf-card-value">${p.unit==="ms"?H(p.value):p.value.toFixed(1)}<span class="nc-perf-card-unit"> ${p.unit==="ms"?"":p.unit}</span></div>
        </div>`).join(""):'<div class="nc-perf-empty">No metrics available yet</div>',f=["script","css","img","font","other"],g=i.reduce((p,b)=>p+b.size,0),x=f.filter(p=>u.has(p)).map(p=>{const b=u.get(p),Fe=g>0?b.totalSize/g*100:0;return`<div class="nc-perf-bar-wrap">
          <span class="nc-perf-bar-label">${p} (${b.count})</span>
          <div class="nc-perf-bar-track"><div class="nc-perf-bar-fill nc-perf-bar-fill-${p}" style="width:${Math.max(Fe,1)}%"></div></div>
          <span class="nc-perf-bar-value">${q(b.totalSize)}</span>
        </div>`}).join(""),y=i.slice(0,30).map(p=>`
      <tr>
        <td title="${h(p.name)}">${h(Me(p.name))}</td>
        <td>${p.type}</td>
        <td>${H(p.duration)}</td>
        <td>${q(p.size)}</td>
      </tr>`).join(""),T=c.length>0?c.slice(0,20).map(p=>`
        <tr>
          <td>${H(p.startTime)}</td>
          <td style="color:${p.duration>100?"var(--nc-error)":"var(--nc-warn)"}">${H(p.duration)}</td>
        </tr>`).join(""):"",L=performance.getEntriesByType("mark"),E=L.length>0?L.map(p=>`
        <tr>
          <td>${h(p.name)}</td>
          <td>${H(p.startTime)}</td>
        </tr>`).join(""):"";o.innerHTML=`
      <div class="nc-perf-view">
        <div class="nc-toolbar">
          <button class="nc-toolbar-btn nc-perf-refresh">Refresh</button>
          <button class="nc-perf-mark-btn nc-perf-mark">+ Mark</button>
        </div>
        <div class="nc-perf-scroll">
          <div class="nc-perf-section">
            <div class="nc-perf-section-title">Core Metrics</div>
            <div class="nc-perf-metrics">${d}</div>
          </div>

          ${x?`
          <div class="nc-perf-section">
            <div class="nc-perf-section-title">Resource Breakdown (${i.length} resources, ${q(g)} total)</div>
            ${x}
          </div>`:""}

          ${y?`
          <div class="nc-perf-section">
            <div class="nc-perf-section-title">Slowest Resources</div>
            <table class="nc-perf-table">
              <tr><th>Name</th><th>Type</th><th>Duration</th><th>Size</th></tr>
              ${y}
            </table>
          </div>`:""}

          ${T?`
          <div class="nc-perf-section">
            <div class="nc-perf-section-title">Long Tasks (${c.length})</div>
            <table class="nc-perf-table">
              <tr><th>Start</th><th>Duration</th></tr>
              ${T}
            </table>
          </div>`:""}

          ${E?`
          <div class="nc-perf-section">
            <div class="nc-perf-section-title">Performance Marks</div>
            <table class="nc-perf-table">
              <tr><th>Name</th><th>Time</th></tr>
              ${E}
            </table>
          </div>`:""}
        </div>
      </div>`,o.querySelector(".nc-perf-refresh").addEventListener("click",s),o.querySelector(".nc-perf-mark").addEventListener("click",()=>{const p=`nc-mark-${n.length+1}`;performance.mark(p),n.push(p),s()})}return{name:"performance",version:"1.0.0",init(){try{e=new PerformanceObserver(r=>{for(const i of r.getEntries())t.push({startTime:i.startTime,duration:i.duration})}),e.observe({type:"longtask",buffered:!0})}catch{}},tab:{label:"Perf",render(r,i){o=r,i.addStyle(Re),s()},destroy(){o.innerHTML=""}},destroy(){e?.disconnect(),e=null,t=[];for(const r of n)try{performance.clearMarks(r)}catch{}n=[]}}}let P=null;class j{constructor(e){P&&P.destroy(),P=this,this.panel=new Ee(e),this.panel.init()}show(){this.panel.show()}hide(){this.panel.hide()}toggle(){this.panel.toggle()}get isVisible(){return this.panel.isVisible()}appendStream(e,t){this.panel.getConsoleCore().appendStream(e,t)}endStream(e){this.panel.getConsoleCore().endStream(e)}setTheme(e){this.panel.setTheme(e)}clearConsole(){this.panel.getConsoleCore().clear()}clearNetwork(){this.panel.getNetworkCore().clear()}exportLogs(){return this.panel.getConsoleCore().exportJSON()}getLogEntries(){return this.panel.getConsoleCore().getEntries()}getNetworkEntries(){return this.panel.getNetworkCore().getEntries()}use(e){return this.panel.use(e),this}destroy(){P===this&&(P=null),this.panel.destroy()}}k.NextConsole=j,k.createPerformancePlugin=Be,k.createSourcePlugin=Ce,k.default=j,Object.defineProperties(k,{__esModule:{value:!0},[Symbol.toStringTag]:{value:"Module"}})});
//# sourceMappingURL=nextconsole.umd.js.map
