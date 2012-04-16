
({
	appDir: '../app',
	dir: '../build',
	baseUrl: 'js',
	modules: [
		  { name: 'main' }
		, { name: 'eg/eg_api' }
		, { name: 'opac/search', exclude: ['base', 'eg/eg_api'] }
		, { name: 'opac/edit_hold', exclude: ['base', 'eg/eg_api', 'opac/ou_tree', 'opac/cover_art'] }
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
