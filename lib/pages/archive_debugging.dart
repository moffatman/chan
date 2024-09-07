import 'package:chan/pages/board.dart';
import 'package:chan/services/persistence.dart';
import 'package:chan/models/thread.dart';
import 'package:chan/models/search.dart';
import 'package:chan/models/post.dart';
import 'package:chan/models/board.dart';

import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/widgets/adaptive.dart';
import 'package:chan/widgets/scroll_tracker.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

class WrappedArchive extends ImageboardSite {
	final ImageboardSiteArchive archive;
	WrappedArchive(this.archive) : super(
    archives: const [],
    overrideUserAgent: archive.overrideUserAgent
  );

  @override
  List<ImageboardSiteArchive> get archives => [];

  @override
  Dio get client => archive.client;

  @override
  Future<PostReceipt> submitPost(DraftPost post, CaptchaSolution captchaSolution, CancelToken cancelToken) {
    throw UnimplementedError();
  }

  @override
  Future<List<ImageboardBoard>> getBoards({required RequestPriority priority}) {
    return archive.getBoards(priority: priority);
  }

  @override
  Future<CaptchaRequest> getCaptchaRequest(String board, [int? threadId]) async {
    throw UnimplementedError();
  }

  @override
  Future<List<Thread>> getCatalogImpl(String board, {CatalogVariant? variant, required RequestPriority priority}) {
    return archive.getCatalogImpl(board, variant: variant, priority: priority);
  }

  @override
  Future<List<Thread>> getMoreCatalogImpl(String board, Thread after, {CatalogVariant? variant, required RequestPriority priority}) {
    return archive.getMoreCatalogImpl(board, after, variant: variant, priority: priority);
  }

  @override
  Future<Post> getPost(String board, int id, {required RequestPriority priority}) {
    return archive.getPost(board, id, priority: priority);
  }

  @override
  Future<Post> getPostFromArchive(String board, int id, {required RequestPriority priority}) {
    return archive.getPost(board, id, priority: priority);
  }

  @override
  Future<Thread> getThreadImpl(ThreadIdentifier thread, {ThreadVariant? variant, required RequestPriority priority}) {
    return archive.getThread(thread, priority: priority);
  }

  @override
  Future<Thread> getThreadFromArchive(ThreadIdentifier thread, {Future<void> Function(Thread)? customValidator, required RequestPriority priority}) {
    return archive.getThread(thread, priority: priority);
  }

  @override
  String getWebUrlImpl(String board, [int? threadId, int? postId]) {
    throw UnimplementedError();
  }

  @override
  String get name => archive.name;

  @override
  bool get hasPagedCatalog => archive.hasPagedCatalog;

  @override
  Future<ImageboardArchiveSearchResultPage> search(ImageboardArchiveSearchQuery query, {required int page, ImageboardArchiveSearchResultPage? lastResult}) {
    return archive.search(query, page: page, lastResult: lastResult);
  }

  @override
  String get siteType => 'debugging';
  @override
  String get siteData => '';
  
  @override
  Future<BoardThreadOrPostIdentifier?> decodeUrl(String url) async => null;

  @override
  Uri get iconUrl => Uri.https('google.com', '/favicon.ico');
  
  @override
  String get defaultUsername => '';
  
  @override
  String get baseUrl => 'www.example.com';
}

class ArchiveDebuggingPage extends StatelessWidget {
	const ArchiveDebuggingPage({
		Key? key
	}) : super(key: key);

	@override
	Widget build(BuildContext context) {
		final site = context.watch<ImageboardSite>();
		return AdaptiveScaffold(
			bar: const AdaptiveBar(
				title: Text('Archive debugging')
			),
			body: ListView.builder(
        itemCount: site.archives.length,
        itemBuilder: (context, i) => Container(
          padding: const EdgeInsets.all(16),
          alignment: Alignment.center,
          child: CupertinoButton(
            child: Text(site.archives[i].name),
            onPressed: () {
              final t = ThreadIdentifier('g', 72382464);
              context.read<Persistence>().getThreadStateIfExists(t)?.delete();
              Navigator.of(context).push(CupertinoPageRoute(
                builder: (context) => Provider<ImageboardSite>.value(
                  value: WrappedArchive(site.archives[i]),
                  child: Navigator(
                    observers: [ScrollTrackerNavigatorObserver()],
                    initialRoute: '/',
                    onGenerateRoute: (settings) => adaptivePageRoute(
                      builder: (context) => const BoardPage(
                        initialBoard: null,
                        semanticId: -1
                      )
                    )
                  )
                )
              ));
            }
          )
        )
      )
    );
	}
}