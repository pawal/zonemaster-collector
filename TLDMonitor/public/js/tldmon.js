$.fn.dataTable.ext.type.order['loglevel-grade-pre'] = function ( d ) {
  switch ( d ) {
    case 'DEBUG':    return 1;
    case 'INFO':     return 2;
    case 'NOTICE':   return 3;
    case 'WARNING':  return 4;
    case 'ERROR':    return 5;
    case 'CRITICAL': return 6;
  }
  return 0;
};
					     
$(document).foundation();

$(document).ready(function() {
  $('#tldlist').DataTable( {
      "lengthMenu": [[20, 50, 100, -1], [20, 50, 100, "All"]],
      "columnDefs": [ {
	  "type": "loglevel-grade",
	  "targets": -1
      } ]
  } );
} );

$(document).ready(function() {
  $('#tldlog').DataTable( {
      "lengthMenu": [[-1, 20, 50, 100], ["All", 20, 50, 100]],
      "paging":   false,
      "columnDefs": [ { "type": "loglevel-grade", "targets": 1 } ],
      "aaSorting": []
  } );
} );
