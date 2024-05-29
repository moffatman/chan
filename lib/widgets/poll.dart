import 'package:chan/services/settings.dart';
import 'package:chan/sites/imageboard_site.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

class PollWidget extends StatelessWidget {
	final ImageboardPoll poll;

	const PollWidget({
		required this.poll,
		super.key
	});
	
	@override
	Widget build(BuildContext context) {
		final theme = context.watch<SavedTheme>();
		final total = poll.rows.fold(0, (s, r) => s + r.votes);
		return Container(
			padding: const EdgeInsets.all(16),
			color: theme.backgroundColor,
			child: Column(
				mainAxisSize: MainAxisSize.min,
				crossAxisAlignment: CrossAxisAlignment.start,
				children: [
					Text(poll.title ?? (total > 0 ? 'Poll Results' : 'Poll Options'), style: const TextStyle(
						fontSize: 30,
						fontWeight: FontWeight.bold
					)),
					const SizedBox(height: 16),
					for (int i = 0; i < poll.rows.length; i++) ...[
						Text(poll.rows[i].name),
						const SizedBox(height: 4),
						if (total > 0) Row(
							children: [
								Flexible(
									fit: FlexFit.tight,
									flex: poll.rows[i].votes,
									child: DecoratedBox(
										decoration: BoxDecoration(
											borderRadius: const BorderRadius.only(
												topRight: Radius.circular(8),
												bottomRight: Radius.circular(8)
											),
											color: (poll.rows[i].color ?? theme.primaryColor)
										),
										child: const SizedBox(height: 30)
									)
								),
								Text('  ${poll.rows[i].votes}', style: TextStyle(
									color: theme.primaryColor,
									fontWeight: FontWeight.bold
								)),
								Flexible(
									fit: FlexFit.tight,
									flex: total - poll.rows[i].votes,
									child: const SizedBox()
								)
							]
						),
						if (i != poll.rows.length - 1) const SizedBox(height: 16)
					]
				]
			)
		);
	}
}