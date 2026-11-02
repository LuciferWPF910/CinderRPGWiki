/* Cinder design kit scripts (Module:Kit). Loaded by one line in
   MediaWiki:Common.js. Turns {{Tabs}} into clickable tabs; without this
   script the tab contents simply show one after another. */
mw.hook('wikipage.content').add(function ($content) {
	$content.find('.cw-k-tabs').not('.cw-k-tabs-ready').each(function () {
		var $tabs = $(this);
		var $panels = $tabs.children('.cw-k-tab-panel');
		if (!$panels.length) {
			return;
		}
		var fallback = $panels.first().children('.cw-k-tab-fallback')[0];
		var custom = fallback && fallback.style ? fallback.style.borderBottomColor : '';
		var $bar = $('<div class="cw-k-tab-bar" role="tablist"></div>');
		function show(index) {
			$bar.children().each(function (i) {
				var active = i === index;
				$(this).toggleClass('cw-k-tab-active cw-a-bb', active)
					.attr('aria-selected', active ? 'true' : 'false')
					.css('border-bottom-color', active && custom ? custom : '');
			});
			$panels.each(function (i) {
				$(this).toggleClass('cw-k-tab-shown', i === index);
			});
		}
		$panels.each(function (i) {
			var label = $(this).attr('data-label') || ('Tab ' + (i + 1));
			$('<button type="button" class="cw-k-tab-btn" role="tab"></button>')
				.text(label)
				.on('click', function () {
					show(i);
				})
				.appendTo($bar);
		});
		$tabs.prepend($bar).addClass('cw-k-tabs-ready');
		show(0);
	});
});

/* ------------------------------------------------------------------
   Interactive maps ({{Map}}, Module:Map).
   Zoom with the buttons, Ctrl + scroll, a pinch, or the scroll wheel in
   fullscreen; drag to pan when zoomed. Filters are remembered per map in
   this browser. Logged-in editors get an "Add marker" button that shows
   the {{Map marker}} code for wherever they click.
   ------------------------------------------------------------------ */
(function () {
	var MIN_SCALE = 1;
	var MAX_SCALE = 8;
	var STEP = 1.5;
	var DRAG_SLOP = 4;
	var HINT_MS = 1600;
	var STORE_PREFIX = 'cw-map-off:';

	function storeGet(key) {
		try {
			return window.localStorage.getItem(key);
		} catch (e) {
			return null;
		}
	}
	function storeSet(key, value) {
		try {
			window.localStorage.setItem(key, value);
		} catch (e) {}
	}
	function el(tag, cls, text) {
		var e = document.createElement(tag);
		if (cls) {
			e.className = cls;
		}
		if (text !== undefined) {
			e.textContent = text;
		}
		return e;
	}
	function fullscreenElement() {
		return document.fullscreenElement || document.webkitFullscreenElement || null;
	}

	function setup(map, index) {
		var view = map.querySelector('.cw-map-view');
		var stage = map.querySelector('.cw-map-stage');
		if (!view || !stage) {
			return;
		}
		var img = stage.querySelector('.cw-map-img img');
		var markers = Array.prototype.slice.call(map.querySelectorAll('.cw-map-mk'));
		var s = 1, tx = 0, ty = 0;
		var world = (map.getAttribute('data-world') || '').split(',').map(Number);
		var hasWorld = world.length === 4 && world.every(function (n) { return isFinite(n); });
		var size = parseInt(map.getAttribute('data-size'), 10);
		var storeKey = STORE_PREFIX + mw.config.get('wgPageName') + ':' + index;

		if (img) {
			img.setAttribute('draggable', 'false');
		}

		/* ---- Zoom and pan ---- */
		function clampPan() {
			var w = stage.offsetWidth, h = stage.offsetHeight;
			tx = Math.min(0, Math.max(w - w * s, tx));
			ty = Math.min(0, Math.max(h - h * s, ty));
		}
		function apply(smooth) {
			map.classList.toggle('cw-map-smooth', !!smooth);
			stage.style.transform = 'translate(' + tx + 'px,' + ty + 'px) scale(' + s + ')';
			var inv = 'scale(' + (1 / s) + ')';
			for (var i = 0; i < markers.length; i++) {
				markers[i].style.transform = inv;
			}
			view.style.touchAction = s > 1 ? 'none' : 'pan-y';
		}
		function zoomAt(clientX, clientY, factor, smooth) {
			var r = stage.getBoundingClientRect();
			var px = (clientX - r.left) / s, py = (clientY - r.top) / s;
			var ns = Math.min(MAX_SCALE, Math.max(MIN_SCALE, s * factor));
			tx += px * (s - ns);
			ty += py * (s - ns);
			s = ns;
			clampPan();
			apply(smooth);
		}
		function zoomCentre(factor) {
			var r = view.getBoundingClientRect();
			zoomAt(r.left + r.width / 2, r.top + r.height / 2, factor, true);
		}
		function reset() {
			s = 1;
			tx = 0;
			ty = 0;
			apply(true);
		}

		/* ---- Hint ---- */
		var hint = el('div', 'cw-map-hint');
		hint.style.pointerEvents = 'none';
		view.appendChild(hint);
		var hintTimer = null;
		function showHint(text) {
			hint.textContent = text;
			hint.classList.add('cw-map-hint-on');
			clearTimeout(hintTimer);
			hintTimer = setTimeout(function () {
				hint.classList.remove('cw-map-hint-on');
			}, HINT_MS);
		}

		/* ---- Popups ---- */
		function closePopups(except) {
			for (var i = 0; i < markers.length; i++) {
				if (markers[i] !== except) {
					markers[i].classList.remove('cw-map-mk-open');
				}
			}
		}
		markers.forEach(function (m) {
			if (size > 0) {
				m.style.width = size + 'px';
				m.style.height = size + 'px';
				m.style.margin = (-size / 2) + 'px 0 0 ' + (-size / 2) + 'px';
				var mi = m.querySelector('img');
				if (mi) {
					mi.style.width = (size - 2) + 'px';
					mi.style.height = (size - 2) + 'px';
				}
			}
			m.setAttribute('tabindex', '0');
			m.setAttribute('role', 'button');
			if (hasWorld) {
				var x = parseFloat(m.getAttribute('data-x')), y = parseFloat(m.getAttribute('data-y'));
				var pop = m.querySelector('.cw-map-pop');
				if (pop && isFinite(x) && isFinite(y)) {
					var wx = Math.round(world[0] + (world[2] - world[0]) * x / 100);
					var wz = Math.round(world[1] + (world[3] - world[1]) * y / 100);
					pop.appendChild(el('div', 'cw-map-pop-coords', 'X ' + wx + ', Z ' + wz));
				}
			}
			function toggle() {
				closePopups(m);
				m.classList.toggle('cw-map-mk-open');
			}
			m.addEventListener('click', function (e) {
				if (picking || moved) {
					return;
				}
				if (e.target.closest('a')) {
					return;
				}
				e.stopPropagation();
				toggle();
			});
			m.addEventListener('keydown', function (e) {
				if (e.key === 'Enter' || e.key === ' ') {
					e.preventDefault();
					toggle();
				}
			});
		});

		/* ---- Filters ---- */
		var types = [], byType = {};
		markers.forEach(function (m) {
			var t = m.getAttribute('data-type') || 'poi';
			if (!byType[t]) {
				byType[t] = { label: m.getAttribute('data-label') || t, markers: [], sample: m };
				types.push(t);
			}
			byType[t].markers.push(m);
		});
		var off = {};
		var saved = storeGet(storeKey);
		var initial = saved !== null ? saved : (map.getAttribute('data-hidden') || '');
		initial.split(',').forEach(function (t) {
			if (t) {
				off[t] = true;
			}
		});
		var boxes = {};
		var allBox = null;
		function applyFilters(save) {
			types.forEach(function (t) {
				byType[t].markers.forEach(function (m) {
					m.classList.toggle('cw-map-mk-off', !!off[t]);
				});
				if (boxes[t]) {
					boxes[t].checked = !off[t];
				}
			});
			if (allBox) {
				allBox.checked = types.every(function (t) { return !off[t]; });
			}
			if (save) {
				storeSet(storeKey, Object.keys(off).filter(function (t) { return off[t]; }).join(','));
			}
		}
		if (types.length) {
			var filters = el('div', 'cw-map-filters');
			var toggleBtn = el('button', 'cw-map-btn cw-map-filter-toggle', 'FILTERS \u25BE');
			toggleBtn.type = 'button';
			var list = el('div', 'cw-map-filter-list');
			toggleBtn.addEventListener('click', function (e) {
				e.stopPropagation();
				list.style.maxHeight = Math.max(120, view.clientHeight - 70) + 'px';
				filters.classList.toggle('cw-map-filters-open');
			});
			var allRow = el('label', 'cw-map-filter cw-map-filter-all');
			allBox = el('input');
			allBox.type = 'checkbox';
			allBox.addEventListener('change', function () {
				types.forEach(function (t) {
					off[t] = !allBox.checked;
				});
				applyFilters(true);
			});
			allRow.appendChild(allBox);
			allRow.appendChild(el('span', '', 'Show all'));
			list.appendChild(allRow);
			types.forEach(function (t) {
				var row = el('label', 'cw-map-filter');
				var box = el('input');
				box.type = 'checkbox';
				box.addEventListener('change', function () {
					off[t] = !box.checked;
					applyFilters(true);
				});
				boxes[t] = box;
				row.appendChild(box);
				var sampleImg = byType[t].sample.querySelector('img');
				var sampleDot = byType[t].sample.querySelector('.cw-map-dot');
				if (sampleImg) {
					var icon = el('img');
					icon.src = sampleImg.currentSrc || sampleImg.src;
					icon.alt = '';
					row.appendChild(icon);
				} else if (sampleDot) {
					var dot = el('span', 'cw-map-dot');
					dot.style.backgroundColor = sampleDot.style.backgroundColor;
					row.appendChild(dot);
				}
				row.appendChild(el('span', '', byType[t].label));
				row.appendChild(el('span', 'cw-map-filter-count', String(byType[t].markers.length)));
				list.appendChild(row);
			});
			filters.appendChild(toggleBtn);
			filters.appendChild(list);
			view.appendChild(filters);
		}
		applyFilters(false);

		/* ---- Buttons ---- */
		var controls = el('div', 'cw-map-controls');
		function button(text, title, fn) {
			var b = el('button', 'cw-map-btn', text);
			b.type = 'button';
			b.title = title;
			b.setAttribute('aria-label', title);
			b.addEventListener('click', function (e) {
				e.stopPropagation();
				fn(b);
			});
			controls.appendChild(b);
			return b;
		}
		button('+', 'Zoom in', function () { zoomCentre(STEP); });
		button('\u2212', 'Zoom out', function () { zoomCentre(1 / STEP); });
		button('\u27F2', 'Reset view', reset);
		var canFull = !!(map.requestFullscreen || map.webkitRequestFullscreen);
		if (canFull) {
			button('\u26F6', 'Fullscreen', function () {
				if (fullscreenElement() === map) {
					(document.exitFullscreen || document.webkitExitFullscreen).call(document);
				} else {
					(map.requestFullscreen || map.webkitRequestFullscreen).call(map);
				}
			});
		}
		var picking = false;
		var pin = null, pickBox = null;
		if (mw.config.get('wgUserName')) {
			button('\u2316', 'Add marker: click the map to get its code', function (b) {
				picking = !picking;
				b.classList.toggle('cw-map-btn-on', picking);
				map.classList.toggle('cw-map-picking', picking);
				if (picking) {
					showHint('Click the map where the marker should go');
				} else {
					if (pin) { pin.remove(); pin = null; }
					if (pickBox) { pickBox.remove(); pickBox = null; }
				}
			});
		}
		view.appendChild(controls);

		function pickAt(clientX, clientY) {
			var r = stage.getBoundingClientRect();
			var x = Math.max(0, Math.min(100, (clientX - r.left) / r.width * 100));
			var y = Math.max(0, Math.min(100, (clientY - r.top) / r.height * 100));
			x = Math.round(x * 10) / 10;
			y = Math.round(y * 10) / 10;
			if (!pin) {
				pin = el('div', 'cw-map-pin');
				pin.style.pointerEvents = 'none';
				stage.querySelector('.cw-map-markers').appendChild(pin);
			}
			pin.style.left = x + '%';
			pin.style.top = y + '%';
			pin.style.transform = 'scale(' + (1 / s) + ')';
			var firstType = types.filter(function (t) { return !off[t]; })[0] || 'poi';
			var code = '{{Map marker|' + firstType + '|' + x + '|' + y + '}}';
			if (!pickBox) {
				pickBox = el('div', 'cw-map-pick');
				view.appendChild(pickBox);
			}
			pickBox.textContent = '';
			pickBox.appendChild(el('div', '', 'Marker code (change the type if needed):'));
			pickBox.appendChild(el('code', '', code));
			if (hasWorld) {
				pickBox.appendChild(el('div', '', 'In game: X ' + Math.round(world[0] + (world[2] - world[0]) * x / 100) +
					', Z ' + Math.round(world[1] + (world[3] - world[1]) * y / 100)));
			}
			var copy = el('button', 'cw-map-btn', 'Copy');
			copy.type = 'button';
			copy.style.display = 'inline-flex';
			copy.style.fontSize = '13px';
			copy.addEventListener('click', function (e) {
				e.stopPropagation();
				var done = function () { copy.textContent = 'Copied'; };
				if (navigator.clipboard && navigator.clipboard.writeText) {
					navigator.clipboard.writeText(code).then(done, function () { window.prompt('Copy this:', code); });
				} else {
					window.prompt('Copy this:', code);
				}
			});
			pickBox.appendChild(copy);
		}

		/* ---- Pointer input: drag, pinch, pick ---- */
		var pointers = {};
		var moved = false;
		var startX = 0, startY = 0, lastDist = 0;
		function pointerCount() {
			return Object.keys(pointers).length;
		}
		var UI = '.cw-map-controls, .cw-map-filters, .cw-map-pick';
		view.addEventListener('pointerdown', function (e) {
			if ((e.button !== undefined && e.button !== 0) || e.target.closest(UI)) {
				return;
			}
			pointers[e.pointerId] = { x: e.clientX, y: e.clientY };
			moved = false;
			startX = e.clientX;
			startY = e.clientY;
			if (pointerCount() === 2) {
				var ids = Object.keys(pointers);
				lastDist = Math.hypot(pointers[ids[0]].x - pointers[ids[1]].x, pointers[ids[0]].y - pointers[ids[1]].y);
			}
		});
		view.addEventListener('pointermove', function (e) {
			var prev = pointers[e.pointerId];
			if (!prev) {
				return;
			}
			var n = pointerCount();
			if (Math.abs(e.clientX - startX) > DRAG_SLOP || Math.abs(e.clientY - startY) > DRAG_SLOP) {
				moved = true;
			}
			if (n === 2) {
				pointers[e.pointerId] = { x: e.clientX, y: e.clientY };
				var ids = Object.keys(pointers);
				var a = pointers[ids[0]], b = pointers[ids[1]];
				var dist = Math.hypot(a.x - b.x, a.y - b.y);
				if (lastDist > 0) {
					zoomAt((a.x + b.x) / 2, (a.y + b.y) / 2, dist / lastDist, false);
				}
				lastDist = dist;
				e.preventDefault();
				return;
			}
			if (n === 1 && s > 1 && moved) {
				if (!map.classList.contains('cw-map-dragging')) {
					map.classList.add('cw-map-dragging');
					try { view.setPointerCapture(e.pointerId); } catch (err) {}
				}
				tx += e.clientX - prev.x;
				ty += e.clientY - prev.y;
				clampPan();
				apply(false);
				e.preventDefault();
			}
			pointers[e.pointerId] = { x: e.clientX, y: e.clientY };
		});
		function pointerEnd(e) {
			delete pointers[e.pointerId];
			if (pointerCount() < 2) {
				lastDist = 0;
			}
			if (pointerCount() === 0) {
				map.classList.remove('cw-map-dragging');
			}
		}
		view.addEventListener('pointerup', function (e) {
			var wasMoved = moved;
			pointerEnd(e);
			if (!wasMoved && picking && !e.target.closest('.cw-map-mk') && !e.target.closest(UI)) {
				pickAt(e.clientX, e.clientY);
			}
		});
		view.addEventListener('pointercancel', pointerEnd);
		view.addEventListener('click', function (e) {
			if (!e.target.closest('.cw-map-mk') && !e.target.closest(UI)) {
				closePopups(null);
			}
		});
		map.addEventListener('click', function (e) {
			if (!e.target.closest('.cw-map-filters')) {
				var f = map.querySelector('.cw-map-filters');
				if (f) {
					f.classList.remove('cw-map-filters-open');
				}
			}
		});
		view.addEventListener('wheel', function (e) {
			if (e.target.closest(UI)) {
				return;
			}
			if (fullscreenElement() === map || e.ctrlKey) {
				e.preventDefault();
				zoomAt(e.clientX, e.clientY, e.deltaY < 0 ? 1.2 : 1 / 1.2, false);
			} else {
				showHint(canFull ? 'Ctrl + scroll to zoom, or open fullscreen' : 'Ctrl + scroll to zoom');
			}
		}, { passive: false });
		view.addEventListener('dblclick', function (e) {
			if (e.target.closest(UI)) {
				return;
			}
			e.preventDefault();
			zoomAt(e.clientX, e.clientY, STEP, true);
		});

		/* ---- Fullscreen sizing ---- */
		function fitFullscreen() {
			var full = fullscreenElement() === map;
			map.classList.toggle('cw-map-full', full);
			if (full && img && img.naturalWidth) {
				var other = 0;
				Array.prototype.forEach.call(map.querySelectorAll('.cw-map-title, .cw-map-caption'), function (n) {
					other += n.offsetHeight;
				});
				var aspect = img.naturalWidth / img.naturalHeight;
				var w = Math.min(window.innerWidth, (window.innerHeight - other) * aspect);
				stage.style.width = Math.floor(w) + 'px';
			} else {
				stage.style.width = '';
			}
			reset();
		}
		document.addEventListener('fullscreenchange', fitFullscreen);
		document.addEventListener('webkitfullscreenchange', fitFullscreen);
		window.addEventListener('resize', function () {
			clampPan();
			apply(false);
		});
		document.addEventListener('keydown', function (e) {
			if (e.key === 'Escape') {
				closePopups(null);
			}
		});

		map.classList.add('cw-map-ready');
		apply(false);
	}

	mw.hook('wikipage.content').add(function ($content) {
		var maps = $content[0] ? $content[0].querySelectorAll('.cw-map:not(.cw-map-ready)') : [];
		Array.prototype.forEach.call(maps, function (map, i) {
			try {
				setup(map, i);
			} catch (e) {
				if (window.console) {
					console.error('CinderKit map:', e);
				}
			}
		});
	});
}());
