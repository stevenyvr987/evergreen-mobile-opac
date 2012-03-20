
({
	baseUrl: '../js-compile',
	dir: '../js-build',
	modules: [
		  { name: 'main' }
		, { name: 'opac/search', exclude: ['base'] }
		, { name: 'account/summary', exclude: ['base'] }
	],
	paths: {
		jquery: 'empty:',
		jqm: 'empty:',
		json2: 'empty:',
		jsd: 'lib/jsdeferred',
		md5: 'lib/md5',
		jqm_sd: 'lib/jquery.mobile.simpledialog2',
		fmall: 'dojo/fieldmapper/fmall',
		fmd: 'eg/fm_datatypes'
	}
})
