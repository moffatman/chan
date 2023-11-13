import 'package:auto_size_text/auto_size_text.dart';
import 'package:chan/models/search.dart';
import 'package:chan/pages/search_query.dart';
import 'package:chan/services/imageboard.dart';
import 'package:chan/services/share.dart';
import 'package:chan/services/theme.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:chan/widgets/adaptive.dart';
import 'package:chan/util.dart';
import 'package:chan/widgets/imageboard_icon.dart';
import 'package:chan/widgets/util.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class UserInfoPanel extends StatefulWidget {
	final String username;
	final String board;

	const UserInfoPanel({
		required this.username,
		required this.board,
		super.key
	});

	@override
	createState() => _UserInfoPanelState();
}

class _UserInfoPanelState extends State<UserInfoPanel> {
	Future<ImageboardUserInfo>? _future;

	@override
	void initState() {
		super.initState();
		final site = context.read<ImageboardSite>();
		if (site.supportsUserInfo) {
			_future = site.getUserInfo(widget.username).catchError((e, st) {
				Future.error(e, st); // Crashlytics
				Error.throwWithStackTrace(e, st);
			});
		}
	}

	@override
	Widget build(BuildContext context) {
		final site = context.read<ImageboardSite>();
		return Container(
			color: ChanceTheme.backgroundColorOf(context),
			padding: const EdgeInsets.all(16),
			child: FutureBuilder(
				future: _future,
				builder: (context, snapshot) {
					final data = snapshot.data;
					return Column(
						mainAxisSize: MainAxisSize.min,
						crossAxisAlignment: CrossAxisAlignment.center,
						children: [
							Row(
								children: [
									if (site.supportsUserAvatars)
										if (data?.avatar != null) Padding(
											padding: const EdgeInsets.only(right: 16),
											child: ExtendedImage.network(
												data!.avatar!.toString(),
												width: 64,
												height: 64,
												fit: BoxFit.cover
											)
										)
										else const SizedBox(width: 80, height: 64)
									else const Padding(
										padding: EdgeInsets.only(right: 12),
										child: ImageboardIcon(size: 24)
									),
									Expanded(
										child: Text(widget.username, style: const TextStyle(
											fontSize: 20,
											fontWeight: FontWeight.w600
										))
									),
									Builder(
										builder: (context) => AdaptiveIconButton(
											icon: Icon(Adaptive.icons.share),
											onPressed: snapshot.data?.webUrl == null ? null : () {
												final offset = (context.findRenderObject() as RenderBox?)?.localToGlobal(Offset.zero);
												final size = context.findRenderObject()?.semanticBounds.size;
												shareOne(
													context: context,
													text: (snapshot.data?.webUrl).toString(),
													type: "text",
													sharePositionOrigin: (offset != null && size != null) ? offset & size : null,
												);
											}
										)
									)
								]
							),
							if (site.supportsUserInfo) SizedBox(
								height: 100,
								child: Row(
									mainAxisAlignment: MainAxisAlignment.spaceEvenly,
									children: [
										if (snapshot.hasError) Column(
											children: [
												Row(
													mainAxisSize: MainAxisSize.min,
													children: [
														const Icon(CupertinoIcons.exclamationmark_triangle),
														const SizedBox(width: 8),
														Flexible(
															child: Text('Error looking up user data: ${snapshot.error?.toStringDio() ?? 'Unknown'}')
														)
													]
												),
												const SizedBox(height: 16),
												AdaptiveFilledButton(
													padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 32),
													onPressed: () {
														setState(() {
															_future = site.getUserInfo(widget.username).catchError((e, st) {
																Future.error(e, st); // Crashlytics
																Error.throwWithStackTrace(e, st);
															});
														});
													},
													child: const Text('Retry')
												)
											]
										)
										else if (data == null) const CircularProgressIndicator.adaptive()
										else ...[
											('Age', formatRelativeTime(data.createdAt)),
											('Total Score', data.totalKarma.toString()),
											if (data.commentKarma != null) ('Comment Score', data.commentKarma.toString()),
											if (data.linkKarma != null) ('Link Score', data.linkKarma.toString()),
										].map((stat) => Flexible(
											child: Column(
												mainAxisSize: MainAxisSize.min,
												children: [
													Text(stat.$2),
													const SizedBox(height: 4),
													AutoSizeText(stat.$1, minFontSize: 10, textAlign: TextAlign.center)
												]
											)
										))
									]
								)
							),
							AdaptiveFilledButton(
								onPressed: (site.supportsSearch(widget.board).options.name || site.supportsSearch(null).options.name) ? () {
									openSearch(context: context, query: ImageboardArchiveSearchQuery(
										imageboardKey: context.read<Imageboard>().key,
										boards: site.supportsSearch(null).options.name ? [] : [widget.board],
										name: widget.username
									));
								} : null,
								child: Row(
									mainAxisSize: MainAxisSize.min,
									children: [
										const Icon(CupertinoIcons.person_fill),
										const SizedBox(width: 8),
										Text('Search ${site.supportsSearch(null).options.name ? site.name : site.formatBoardName(widget.board)}')
									]
								)
							)
						]
					);
				}
			)
		);
	}
}