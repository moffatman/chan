put this in your browser and it will work 
    // ==UserScript==
// @name         4chan TCaptcha ImGui - Large UI + NO_PAIR XOR Support
// @namespace    4chan-gradio-client
// @match        https://*.4chan.org/*
// @match        https://*.4channel.org/*
// @grant        unsafeWindow
// @grant        GM_xmlhttpRequest
// @run-at       document-end
// @version      18.0
// ==/UserScript==

const CONFIG = Object.freeze({
    GRADIO: Object.freeze({
        // SERVER_URL: 'http://localhost:7860',
        SERVER_URL: 'https://jihadist324r-4chanopenncvsolver1.hf.space',
        BATCH_ENDPOINT: '/api/batch',
        DIE_ENDPOINT: '/api/die/batch', // New endpoint for specialized CV
        TIMEOUT: 20000,
        RETRY_ATTEMPTS: 3,
        RETRY_DELAY: 1000
    }),
    UI: Object.freeze({
        WIDTH: 850,
        COLORS: Object.freeze({
            PRIMARY: '#007acc',
            PREDICT: '#ff3e3e',
            BG_DARK: '#1e1e1e',
            BG_HEADER: '#252526',
            BG_LOG: '#111111',
            BG_CARD: '#2d2d2d',
            BG_PREDICTED: '#452121',
            BORDER: '#333',
            BORDER_CARD: '#444',
            TEXT: '#eee',
            TEXT_MUTED: '#888',
            TEXT_SUCCESS: '#6a9955',
            TEXT_LOG: '#cccccc',
            TEXT_WARN: '#dcdcaa',
            TEXT_ERROR: '#f44747',
            TEXT_INFO: '#569cd6'
        })
    }),
    TIMING: Object.freeze({
        HOOK_RETRY: 250,
        UPDATE_DELAY: 150,
        AUTO_SOLVE_DELAY: 800
    }),
    LOGGING: Object.freeze({
        MAX_UI_LINES: 50,
        ENABLED: true
    }),
    AUTO_SOLVE: true,
    AUTO_SUBMIT: true
});

// ═══════════════════════════════════════════════════════════════
// LOGGER SYSTEM
// ═══════════════════════════════════════════════════════════════

class Logger {
    static #container = null;
    static setContainer(element) { this.#container = element; }
    static #timestamp() {
        const d = new Date();
        return `${d.getHours().toString().padStart(2, '0')}:${d.getMinutes().toString().padStart(2, '0')}:${d.getSeconds().toString().padStart(2, '0')}.${d.getMilliseconds().toString().padStart(3, '0')}`;
    }
    static #log(level, message, color) {
        if (!CONFIG.LOGGING.ENABLED) return;
        const ts = this.#timestamp();
        console.log(`%c[TCaptcha] [${ts}] ${message}`, `color: ${color}; font-weight: bold;`);
        if (this.#container) {
            const entry = DOM.create('div', {
                className: 'log-entry',
                html: `<span style="color:#666">[${ts}]</span> <span style="color:${color}">${message}</span>`
            });
            this.#container.appendChild(entry);
            this.#container.scrollTop = this.#container.scrollHeight;
            while (this.#container.childElementCount > CONFIG.LOGGING.MAX_UI_LINES) {
                this.#container.removeChild(this.#container.firstChild);
            }
        }
    }
    static info(msg) { this.#log('INFO', msg, CONFIG.UI.COLORS.TEXT_INFO); }
    static success(msg) { this.#log('SUCCESS', msg, CONFIG.UI.COLORS.TEXT_SUCCESS); }
    static warn(msg) { this.#log('WARN', msg, CONFIG.UI.COLORS.TEXT_WARN); }
    static error(msg) { this.#log('ERROR', msg, CONFIG.UI.COLORS.TEXT_ERROR); }
    static prompt(msg) { this.#log('PROMPT', `>>> ${msg}`, '#d4d4d4'); }
}

// ═══════════════════════════════════════════════════════════════
// GRADIO CLIENT
// ═══════════════════════════════════════════════════════════════

class GradioClient {
    async analyzeBatch(base64Images, endpoint = CONFIG.GRADIO.BATCH_ENDPOINT) {
        const url = `${CONFIG.GRADIO.SERVER_URL}${endpoint}`;
        const cleanImages = base64Images.map(img => img.includes(',') ? img : `data:image/jpeg;base64,${img}`);

        Logger.info(`Sending batch to ${endpoint}...`);
        const startTime = performance.now();

        return new Promise((resolve, reject) => {
            GM_xmlhttpRequest({
                method: 'POST',
                url: url,
                headers: { 'Content-Type': 'application/json' },
                data: JSON.stringify({ images: cleanImages }),
                timeout: CONFIG.GRADIO.TIMEOUT,
                onload: (res) => {
                    if (res.status !== 200) return reject(new Error(`HTTP ${res.status}`));
                    try {
                        const data = JSON.parse(res.responseText);
                        const duration = (performance.now() - startTime).toFixed(0);
                        Logger.success(`Inference received in ${duration}ms`);
                        resolve(data.results || []);
                    } catch (e) { reject(new Error('JSON Parse Error')); }
                },
                onerror: () => reject(new Error('Network Error')),
                ontimeout: () => reject(new Error('Timeout'))
            });
        });
    }
}

// ═══════════════════════════════════════════════════════════════
// UI & LOGIC
// ═══════════════════════════════════════════════════════════════

const DOM = {
    create(tag, attrs = {}, children = []) {
        const el = document.createElement(tag);
        for (const [k, v] of Object.entries(attrs)) {
            if (k === 'className') el.className = v;
            else if (k === 'style' && typeof v === 'object') Object.assign(el.style, v);
            else if (k === 'text') el.textContent = v;
            else if (k === 'html') el.innerHTML = v;
            else if (k.startsWith('on')) el.addEventListener(k.slice(2).toLowerCase(), v);
            else el.setAttribute(k, v);
        }
        children.forEach(c => c && el.appendChild(typeof c === 'string' ? document.createTextNode(c) : c));
        return el;
    },
    $(id) { return document.getElementById(id); }
};

class InstructionParser {
    static parse(html) {
        const unescaped = html.replace(/\\\//g, '/');
        const doc = new DOMParser().parseFromString(unescaped, 'text/html');
        doc.querySelectorAll('*').forEach(el => {
            const style = (el.getAttribute('style') || '').replace(/\s/g, '');
            if (style.includes('opacity:0') || style.includes('visibility:hidden') || (style.includes('display:none') && !style.includes('nnone'))) {
                el.remove();
            }
        });
        const text = doc.body.textContent.toLowerCase().replace(/\s+/g, ' ').trim();

        let type = 'UNKNOWN', target = 0, keyword = 'empty';
        if (text.includes('dotted')) keyword = 'dotted';
        else if (text.includes('empty')) keyword = 'empty';

        if (text.includes('highest') || text.includes('most') || text.includes('maximum')) {
            type = 'MAX';
        } else if (text.includes('exactly')) {
            type = 'EXACT';
            const m = text.match(/exactly\s*(\d+)/) || html.match(/>\s*(\d+)\s*</);
            if (m) target = parseInt(m[1], 10);
        } else if (text.includes('not have a pair') || text.includes('not like the others')) {
            type = 'NO_PAIR';
        }

        Logger.info(`Parser: [${keyword}] [${type}] Target:${target}`);
        return { type, target, keyword, cleanText: text };
    }
}

class Panel {
    constructor() {
        this.root = null;
        this.els = {};
    }

    init() {
        const { WIDTH, COLORS: C } = CONFIG.UI;
        document.head.appendChild(DOM.create('style', { html: `
            #imgui-root {
                position: fixed; top: 40px; right: 20px; width: ${WIDTH}px;
                background: ${C.BG_DARK}; border: 1px solid ${C.BORDER};
                border-top: 5px solid ${C.PRIMARY}; box-shadow: 0 15px 40px rgba(0,0,0,0.9);
                z-index: 2147483647; font-family: 'Segoe UI', 'Consolas', monospace; color: ${C.TEXT}; display: none;
                border-radius: 8px; overflow: hidden;
            }
            .imgui-header { background: ${C.BG_HEADER}; padding: 12px 16px; cursor: move; display: flex; justify-content: space-between; font-size: 14px; font-weight: bold; border-bottom: 1px solid ${C.BORDER}; user-select: none; }
            .imgui-body { padding: 20px; }
            .imgui-log-container {
                background: ${C.BG_LOG}; border: 1px solid ${C.BORDER_CARD};
                margin-bottom: 15px; height: 180px; overflow-y: auto;
                padding: 10px; font-size: 13px; line-height: 1.5;
            }
            .log-entry { margin-bottom: 4px; border-bottom: 1px solid #222; padding-bottom: 4px; word-break: break-all; }
            .imgui-grid { display: grid; grid-template-columns: repeat(4, 1fr); gap: 12px; }
            .imgui-card { background: ${C.BG_CARD}; border: 3px solid ${C.BORDER_CARD}; padding: 5px; cursor: pointer; position: relative; border-radius: 6px; transition: transform 0.1s ease; }
            .imgui-card:hover { transform: scale(1.02); }
            .imgui-card img { width: 100%; border-radius: 4px; display: block; }
            .imgui-card.predicted { border-color: ${C.PREDICT}; background: ${C.BG_PREDICTED}; box-shadow: 0 0 15px rgba(255, 62, 62, 0.3); }
            .imgui-badge { position: absolute; top: -10px; left: 50%; transform: translateX(-50%); background: ${C.PREDICT}; color: white; font-size: 11px; padding: 2px 10px; border-radius: 12px; z-index: 10; font-weight: bold; box-shadow: 0 2px 5px rgba(0,0,0,0.5); }
            .imgui-count { font-size: 13px; text-align: center; margin-top: 6px; font-weight: bold; color: ${C.TEXT}; }
            .imgui-status { margin-top: 20px; font-size: 13px; color: ${C.TEXT_MUTED}; display: flex; justify-content: space-between; border-top: 1px solid ${C.BORDER}; padding-top: 10px; }
        `}));

        this.root = DOM.create('div', { id: 'imgui-root' }, [
            DOM.create('div', { className: 'imgui-header', id: 'imgui-hdr' }, [
                DOM.create('span', { text: 'TCAPTCHA ANALYZER - NO_PAIR PATCH' }),
                DOM.create('span', { text: '[X]', style: { cursor: 'pointer', color: '#888' }, onclick: () => this.hide() })
            ]),
            DOM.create('div', { className: 'imgui-body' }, [
                DOM.create('div', { className: 'imgui-log-container', id: 'imgui-log' }),
                DOM.create('div', { className: 'imgui-grid', id: 'imgui-grid' }),
                DOM.create('div', { className: 'imgui-status' }, [
                    DOM.create('span', { id: 'imgui-logic', text: 'Logic: Initializing' }),
                    DOM.create('span', { id: 'imgui-step', text: 'Step: -/-' })
                ])
            ])
        ]);

        document.body.appendChild(this.root);
        this.els = {
            log: DOM.$('imgui-log'),
            grid: DOM.$('imgui-grid'),
            logic: DOM.$('imgui-logic'),
            step: DOM.$('imgui-step'),
            hdr: DOM.$('imgui-hdr')
        };

        Logger.setContainer(this.els.log);
        this.#setupDragging();
    }

    #setupDragging() {
        let mx=0, my=0;
        this.els.hdr.onmousedown = (e) => {
            mx = e.clientX; my = e.clientY;
            document.onmousemove = (e) => {
                const x = mx - e.clientX; const y = my - e.clientY;
                mx = e.clientX; my = e.clientY;
                this.root.style.top = (this.root.offsetTop - y) + "px";
                this.root.style.left = (this.root.offsetLeft - x) + "px";
            };
            document.onmouseup = () => { document.onmousemove = null; document.onmouseup = null; };
        };
    }

    show() { this.root.style.display = 'block'; }
    hide() { this.root.style.display = 'none'; }
    clear() { this.els.grid.innerHTML = ''; }
    updateStatus(step, total, logicText) {
        this.els.step.textContent = `STEP: ${step}/${total}`;
        this.els.logic.textContent = `LOGIC: ${logicText}`;
    }
}

class CaptchaController {
    constructor() {
        this.panel = new Panel();
        this.api = new GradioClient();
        this.lastId = null;
    }

    start() {
        if (!unsafeWindow.TCaptcha?.setTaskId) return setTimeout(() => this.start(), CONFIG.TIMING.HOOK_RETRY);
        this.panel.init();
        this.#hook();
        Logger.success('UI Started - Specialized Die API Support Enabled');
    }

    #hook() {
        const tc = unsafeWindow.TCaptcha;
        ['setTaskId', 'setChallenge', 'setTaskItem', 'onNextClick'].forEach(m => {
            if (typeof tc[m] === 'function') {
                const orig = tc[m];
                tc[m] = (...args) => {
                    const res = orig.apply(tc, args);
                    setTimeout(() => this.#refresh(), CONFIG.TIMING.UPDATE_DELAY);
                    return res;
                };
            }
        });
    }

    async #refresh() {
        const tc = unsafeWindow.TCaptcha;
        const task = tc?.getCurrentTask?.();
        if (!task) { this.lastId = null; this.panel.hide(); return; }

        const id = `${tc.taskId}-${task.items?.length}-${task.str.length}`;
        if (this.lastId === id) return;
        this.lastId = id;

        this.panel.show();
        this.panel.clear();

        const logic = InstructionParser.parse(task.str);
        Logger.prompt(logic.cleanText);
        this.panel.updateStatus((tc.taskId || 0) + 1, tc.tasks.length, `${logic.type}`);

        try {
            let results = [];

            if (logic.type === 'NO_PAIR') {
                // Use the specialized die API for NO_PAIR
                results = await this.api.analyzeBatch(task.items, CONFIG.GRADIO.DIE_ENDPOINT);
            } else {
                // Use the general batch API for MAX/EXACT tasks
                const rawResults = await this.api.analyzeBatch(task.items, CONFIG.GRADIO.BATCH_ENDPOINT);
                results = rawResults.map(res => {
                    const detections = res.detections || [];
                    const filtered = detections.filter(d => d.class.includes(logic.keyword));
                    return { ...res, count: filtered.length };
                });
            }

            this.#process(tc, task.items, results, logic);
        } catch (e) { Logger.error(`Analysis Failed: ${e.message}`); }
    }

    #process(tc, items, results, logic) {
        let bestIdx = -1, bestVal = -1;

        if (logic.type === 'MAX') {
            results.forEach((r, i) => { if (r.count > bestVal) { bestVal = r.count; bestIdx = i; } });
        } else if (logic.type === 'EXACT') {
            let minDiff = Infinity;
            results.forEach((r, i) => {
                const diff = Math.abs(r.count - logic.target);
                if (diff < minDiff) { minDiff = diff; bestIdx = i; bestVal = r.count; }
            });
        } else if (logic.type === 'NO_PAIR') {
            // ═══════════════════════════════════════════════════════════════
            // SPECIALIZED XOR LOGIC
            // ═══════════════════════════════════════════════════════════════
            let xorSum = 0;
            // Iterate through results from /api/die/batch
            results.forEach(res => {
                // res.pips is returned by your computer vision backend
                xorSum ^= (res.pips || 0);
            });

            // The remaining xorSum is the pip count of the unique die
            bestVal = xorSum;
            bestIdx = results.findIndex(r => r.pips === xorSum);

            Logger.success(`XOR Solved! Unique Pip Count: ${bestVal} | Found at Index: ${bestIdx}`);
        }

        Logger.info(`Strategy: ${logic.type} | Target/BestVal: ${bestVal} | Best Index: ${bestIdx}`);

        items.forEach((b64, i) => {
            const isBest = i === bestIdx;
            const res = results[i];

            // Determine text to show based on API used
            const countLabel = logic.type === 'NO_PAIR' ? `Pips: ${res.pips}` : `Found: ${res.count}`;

            const card = DOM.create('div', {
                className: `imgui-card ${isBest ? 'predicted' : ''}`,
                onclick: () => {
                    this.#applyAction(tc, i);
                    tc.onNextClick();
                }
            }, [
                DOM.create('img', { src: b64.includes(',') ? b64 : `data:image/png;base64,${b64}` }),
                isBest ? DOM.create('div', { className: 'imgui-badge', text: 'MATCHED' }) : null,
                DOM.create('div', { className: 'imgui-count', text: countLabel })
            ]);
            this.panel.els.grid.appendChild(card);
        });

        // Trigger Auto-Solve if enabled and a match was found
        if (CONFIG.AUTO_SOLVE && bestIdx !== -1) {
            setTimeout(() => {
                this.#applyAction(tc, bestIdx);
                if (CONFIG.AUTO_SUBMIT) tc.onNextClick();
            }, CONFIG.TIMING.AUTO_SOLVE_DELAY);
        }
    }

    #applyAction(tc, idx) {
        if (!tc.sliderNode) return;
        tc.sliderNode.value = idx + 1;
        tc.sliderNode.dispatchEvent(new Event('input', { bubbles: true }));
        tc.sliderNode.dispatchEvent(new Event('change', { bubbles: true }));
        Logger.info(`Applied Slider -> ${idx + 1}`);
    }
}

new CaptchaController().start();
