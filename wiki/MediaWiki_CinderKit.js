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
