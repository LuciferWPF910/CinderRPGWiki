/* MediaWiki:Common.js for the CinderRPG wiki. Kept in GitHub
   (LuciferWPF910/CinderRPGWiki, wiki/MediaWiki_Common.js) and saved by the
   sync script; edit it there, not on the wiki. */

/* Design kit scripts (tabs). The kit's own code lives in MediaWiki:CinderKit.js. */
mw.loader.load(mw.config.get('wgScript') + '?title=MediaWiki:CinderKit.js&action=raw&ctype=text/javascript');

/* CinderWiki: filter box and copy buttons on Project:Variables. */
mw.hook('wikipage.content').add(function ($content) {
	var $tables = $content.find('table.cw-vars-table');
	if (!$tables.length) {
		return;
	}
	var $box = $('<input type="search" class="cw-vars-search">')
		.attr('placeholder', 'Filter variables...')
		.css({ width: '100%', maxWidth: '30em', padding: '4px 8px', margin: '0 0 1em' });
	$content.find('.cw-vars-filter').first().append($box);
	$box.on('input', function () {
		var q = this.value.toLowerCase();
		$tables.find('tr').each(function () {
			if ($(this).find('th').length) {
				return;
			}
			$(this).toggle(!q || this.textContent.toLowerCase().indexOf(q) !== -1);
		});
	});
	$content.find('code.cw-vars-code').each(function () {
		var $code = $(this);
		var text = $code.text();
		var $btn = $('<button type="button" class="cw-vars-copy">Copy</button>')
			.css({ marginLeft: '6px', fontSize: '85%', cursor: 'pointer' });
		$btn.on('click', function () {
			var done = function () {
				$btn.text('Copied');
				setTimeout(function () { $btn.text('Copy'); }, 1500);
			};
			if (navigator.clipboard && navigator.clipboard.writeText) {
				navigator.clipboard.writeText(text).then(done, function () { window.prompt('Copy this:', text); });
			} else {
				window.prompt('Copy this:', text);
			}
		});
		$code.after($btn);
	});
});
