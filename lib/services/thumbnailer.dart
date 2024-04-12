const _thumbsApiRoot = 'thumbs.chance.surf';

/// To save data usage for sites which don't have their own thumbnailer
Uri generateThumbnailerForUrl(Uri url) => Uri.https(_thumbsApiRoot, '/', {
	'url': url.toString()
});
