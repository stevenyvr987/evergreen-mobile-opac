
({
	baseUrl: '../js-compile',
	dir: '../js-build',
	modules: [
		  { name: 'main' }
		, { name: 'eg/eg_api' }
		, { name: 'opac/search', exclude: ['base', 'eg/eg_api'] }
		, { name: 'account/summary', exclude: ['base', 'eg/eg_api'] }
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
