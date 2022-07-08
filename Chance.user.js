// ==UserScript==
// @name         Open in Chance
// @namespace    https://moffatman.com/
// @version      0.1
// @description  Add a button to 4chan threads to open in Chance
// @author       Callum Moffat
// @include      http://boards.4chan.org/*
// @include      https://boards.4chan.org/*
// @include      http://boards.4channel.org/*
// @include      https://boards.4channel.org/*
// @grant        none
// ==/UserScript==

(function() {
    'use strict';

    if (document.location.pathname.split('/')[2] == 'thread') {
        let button = document.createElement('button')
        document.body.appendChild(button)
        button.innerHTML = 'Open in Chance'
        button.onclick = () => {
            document.location = 'chance://4chan' + document.location.pathname
        }
        button.style.position = 'fixed'
        button.style.right = '10px';
        button.style.bottom= '10px';
        button.style['z-index'] = 3;
    }
})();