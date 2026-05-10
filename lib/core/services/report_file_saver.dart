import 'report_file_saver_base.dart';

import 'report_file_saver_stub.dart'
    if (dart.library.html) 'report_file_saver_web.dart'
    if (dart.library.io) 'report_file_saver_io.dart';

ReportFileSaver createReportFileSaver() => createReportFileSaverImpl();
