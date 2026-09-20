package com.moffatman.chan;

import android.util.Log;

import androidx.annotation.NonNull;

import com.google.android.gms.tasks.Task;
import com.google.mlkit.common.MlKitException;
import com.google.mlkit.common.model.RemoteModelManager;
import com.google.mlkit.nl.languageid.IdentifiedLanguage;
import com.google.mlkit.nl.languageid.LanguageIdentification;
import com.google.mlkit.nl.languageid.LanguageIdentifier;
import com.google.mlkit.nl.translate.TranslateLanguage;
import com.google.mlkit.nl.translate.TranslateRemoteModel;
import com.google.mlkit.nl.translate.Translation;
import com.google.mlkit.nl.translate.Translator;
import com.google.mlkit.nl.translate.TranslatorOptions;

import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.HashSet;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

/**
 * The Android end of the com.moffatman.chan/translation channel, backed by ML
 * Kit's on-device language identification and translation.
 *
 * Both are ordinary Maven dependencies: ML Kit's on-device APIs need no Firebase
 * project, no google-services.json and no google-services Gradle plugin of their
 * own, so translation carries no Firebase configuration with it. Everything runs
 * on the device once a language model has been downloaded, and the models are per
 * language rather than part of the APK.
 */
class MlKitTranslation implements MethodChannel.MethodCallHandler {
	/**
	 * The short made-up tags that the Dart side replaces markup, URLs and
	 * numbers with. Everything that goes through the channel is HTML of that
	 * kind and nothing else.
	 */
	private static final Pattern TAG_PATTERN = Pattern.compile("</?([A-Za-z0-9]+)/?>");
	/** Every ML Kit translation model pairs one language with English. */
	private static final String ENGLISH = TranslateLanguage.ENGLISH;
	// A single dominant language is only trusted above this, the same way the
	// iOS side is picky: posts are short, and a short post often has no clear
	// winner, so the runners up are tried before giving up on the engine.
	private static final float CONFIDENT_LANGUAGE = 0.6f;
	private static final float PLAUSIBLE_LANGUAGE = 0.15f;
	private static final int MAX_SOURCE_LANGUAGE_ATTEMPTS = 3;

	private final LanguageIdentifier languageIdentifier = LanguageIdentification.getClient();
	private final Map<String, Translator> translators = new HashMap<>();

	/** Called when the engine goes away, so that the loaded models are released. */
	void close() {
		languageIdentifier.close();
		for (final Translator translator : translators.values()) {
			translator.close();
		}
		translators.clear();
	}

	@Override
	public void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
		if (call.method.equals("isSupported")) {
			// ML Kit's translation needs API 23 and this app's minSdkVersion is 24
			result.success(true);
			return;
		}
		if (!call.method.equals("translate")) {
			result.notImplemented();
			return;
		}
		final String text = call.argument("text");
		final String target = call.argument("to");
		final Boolean interactive = call.argument("interactive");
		if (text == null || target == null || interactive == null) {
			result.error("ARGUMENTS", "Invalid arguments format", null);
			return;
		}
		final String targetLanguage = translateLanguage(target);
		if (targetLanguage == null) {
			// Not a language this engine knows, so hand the request back to the
			// caller instead of failing: it falls back to its HTTP backend
			result.error("UNSUPPORTED", "ML Kit cannot translate into " + target, null);
			return;
		}
		final Request request = new Request(text, targetLanguage, interactive, result);
		// The recogniser is thoroughly confused by the tags, exactly as on iOS,
		// so it only ever gets to see the text between them
		final String plainText = TAG_PATTERN.matcher(text).replaceAll("");
		if (plainText.codePoints().noneMatch(Character::isLetter)) {
			// Nothing to recognise, so answering null sends the caller to its
			// HTTP backend rather than making it download a model on a guess
			result.success(null);
			return;
		}
		// Possible languages rather than the single favourite: the favourite
		// comes with a 0.5 confidence threshold, which throws away a lot of
		// short posts that the engine could have translated
		languageIdentifier.identifyPossibleLanguages(plainText)
				.addOnSuccessListener(languages -> request.identifySource(languages))
				.addOnFailureListener(e -> {
					Log.w("translation", "Language identification failed", e);
					request.completeWithError("LANGUAGE_IDENTIFICATION_FAILED", e.getMessage(), null);
				});
	}

	/**
	 * TranslateLanguage.fromLanguageTag() only takes bare language codes, so a
	 * tag that carries a region or script subtag is retried without it, and the
	 * answer is null when ML Kit has no such language at all.
	 */
	private static String translateLanguage(String languageTag) {
		final String language = TranslateLanguage.fromLanguageTag(languageTag);
		if (language != null) {
			return language;
		}
		final int subtagEnd = languageTag.indexOf('-');
		if (subtagEnd == -1) {
			return null;
		}
		return TranslateLanguage.fromLanguageTag(languageTag.substring(0, subtagEnd));
	}

	/**
	 * The models a translation needs. Since they each pair a language with
	 * English, English only needs a download of its own when the other side is
	 * English too.
	 */
	private static List<String> requiredModels(String source, String target) {
		final Set<String> languages = new LinkedHashSet<>();
		languages.add(source);
		languages.add(target);
		if (languages.size() > 1) {
			languages.remove(ENGLISH);
		}
		return new ArrayList<>(languages);
	}

	/**
	 * One translator per language pair, kept for as long as the engine lives:
	 * getting one loads a model, so they are worth holding on to.
	 */
	private Translator translatorFor(String source, String target) {
		final String key = source + '>' + target;
		final Translator existing = translators.get(key);
		if (existing != null) {
			return existing;
		}
		final Translator translator = Translation.getClient(new TranslatorOptions.Builder()
				.setSourceLanguage(source)
				.setTargetLanguage(target)
				.build());
		translators.put(key, translator);
		return translator;
	}

	/**
	 * The tags in a piece of compressed HTML, with the one tag that
	 * decompressTranslation can do without left out.
	 */
	private static List<String> tagNames(String html) {
		final List<String> names = new ArrayList<>();
		final Matcher matcher = TAG_PATTERN.matcher(html);
		while (matcher.find()) {
			final String name = matcher.group(1).toLowerCase(Locale.ROOT);
			// The Dart side sends line breaks as <br></br>, so the engine
			// closing or reopening them is expected and harmless
			if (!name.equals("br")) {
				names.add(name);
			}
		}
		return names;
	}

	/**
	 * Whether every tag the Dart side sent is still there. decompressTranslation
	 * looks each one up in the codex it built while compressing, and throws
	 * FormatException('Unexpected translated HTML tag') when it meets one it
	 * never made, so this is the difference between a translated post and a
	 * translation error.
	 */
	private static boolean tagsSurvived(String source, String translated) {
		final List<String> before = tagNames(source);
		final List<String> after = tagNames(translated);
		// Only the tags themselves have to come back, not their order: word
		// order changes between languages, and moving a tag to where its text
		// ended up is exactly what should happen
		Collections.sort(before);
		Collections.sort(after);
		return before.equals(after);
	}

	/**
	 * A piece of compressed HTML whose unrecognised tag names have been swapped
	 * for names the engine shields, and the map that turns them back.
	 */
	private static final class ShieldedTags {
		final String text;
		/** Placeholder name to the name the Dart side's codex knows. */
		final Map<String, String> originals;

		ShieldedTags(String text, Map<String, String> originals) {
			this.text = text;
			this.originals = originals;
		}
	}

	/** Whether a tag name is made of letters and nothing else. */
	private static boolean isAlphabetic(String name) {
		for (int i = 0; i < name.length(); i++) {
			if (!Character.isLetter(name.charAt(i))) {
				return false;
			}
		}
		return !name.isEmpty();
	}

	/**
	 * za, zb, ... zz, zaa, ... - alphabetic, so the engine shields them, and no
	 * name the compressor makes begins with a z, so they are free to use.
	 */
	private static String placeholderName(int index) {
		final StringBuilder name = new StringBuilder();
		int value = index;
		while (value >= 0) {
			name.append((char) ('a' + value % 26));
			value = value / 26 - 1;
		}
		return 'z' + name.reverse().toString();
	}

	/**
	 * The tags the engine shields are the ones it recognises, and it recognises
	 * alphabetic names. The compressor counts c, d, ... z and then a0, a1, ...
	 * because the last of the single letters has nowhere to go, so from the 20th
	 * distinct tag onward a name can carry a digit - and a tag the engine does
	 * not recognise is a tag it can drop, which here means a deleted link or a
	 * deleted quote reference rather than some lost formatting.
	 *
	 * The sequence is shared with the other engines and so is not this one's to
	 * change. Instead the names that carry a digit are swapped for alphabetic
	 * ones on the way in and swapped back on the way out, which leaves the text
	 * whole: the translator sees the whole post, tags and all, and translates it
	 * with the context that crosses a tag boundary intact.
	 */
	private static ShieldedTags shieldTagNames(String html) {
		final Set<String> existing = new HashSet<>();
		final Matcher names = TAG_PATTERN.matcher(html);
		while (names.find()) {
			existing.add(names.group(1));
		}
		final Map<String, String> placeholders = new HashMap<>();
		final Map<String, String> originals = new HashMap<>();
		final Matcher matcher = TAG_PATTERN.matcher(html);
		final StringBuffer rewritten = new StringBuffer();
		int nextPlaceholder = 0;
		while (matcher.find()) {
			final String name = matcher.group(1);
			String replacement = name;
			if (!isAlphabetic(name)) {
				replacement = placeholders.get(name);
				if (replacement == null) {
					do {
						replacement = placeholderName(nextPlaceholder++);
					} while (existing.contains(replacement) || originals.containsKey(replacement));
					placeholders.put(name, replacement);
					originals.put(replacement, name);
				}
			}
			matcher.appendReplacement(rewritten,
					Matcher.quoteReplacement(matcher.group().replace(name, replacement)));
		}
		matcher.appendTail(rewritten);
		return new ShieldedTags(rewritten.toString(), originals);
	}

	/**
	 * Puts the names the Dart side knows back, so that decompressTranslation
	 * finds every one of them in the codex it built while compressing.
	 */
	private static String restoreTagNames(String translated, Map<String, String> originals) {
		final Matcher matcher = TAG_PATTERN.matcher(translated);
		final StringBuffer restored = new StringBuffer();
		while (matcher.find()) {
			final String name = matcher.group(1);
			final String original = originals.get(name.toLowerCase(Locale.ROOT));
			final String tag = original == null ? matcher.group() : matcher.group().replace(name, original);
			matcher.appendReplacement(restored, Matcher.quoteReplacement(tag));
		}
		matcher.appendTail(restored);
		return restored.toString();
	}

	private final class Request {
		final String text;
		final String target;
		final boolean interactive;
		final MethodChannel.Result result;
		final List<String> sourceLanguages = new ArrayList<>();
		int nextSourceLanguage;
		boolean completed;
		/** The language whose model is missing, as far as the user is concerned. */
		String missingModelLanguage;
		String failureCode = "TRANSLATION_FAILED";
		String failure;
		boolean didFail;

		Request(String text, String target, boolean interactive, MethodChannel.Result result) {
			this.text = text;
			this.target = target;
			this.interactive = interactive;
			this.result = result;
		}

		void identifySource(List<IdentifiedLanguage> languages) {
			if (languages.isEmpty()) {
				complete(null);
				return;
			}
			if (languages.get(0).getConfidence() > CONFIDENT_LANGUAGE) {
				sourceLanguages.add(languages.get(0).getLanguageTag());
			}
			else {
				for (final IdentifiedLanguage language : languages) {
					if (sourceLanguages.size() >= MAX_SOURCE_LANGUAGE_ATTEMPTS) {
						break;
					}
					if (language.getConfidence() > PLAUSIBLE_LANGUAGE) {
						sourceLanguages.add(language.getLanguageTag());
					}
				}
			}
			if (sourceLanguages.isEmpty()) {
				// No language stands out, so let the HTTP backend take a turn
				// rather than asking the user to download a model for a coin flip
				complete(null);
				return;
			}
			attemptNextSourceLanguage();
		}

		void attemptNextSourceLanguage() {
			while (nextSourceLanguage < sourceLanguages.size()) {
				final String source = translateLanguage(sourceLanguages.get(nextSourceLanguage++));
				if (source == null) {
					// Language identification knows more languages than the
					// translator does, so this one is simply not for us
					continue;
				}
				if (source.equals(target)) {
					// Already in the target language
					complete(text);
					return;
				}
				final Translator translator = translatorFor(source, target);
				if (!interactive) {
					checkModelsDownloaded(translator, source, requiredModels(source, target), 0);
					return;
				}
				// They asked for this translation themselves, so do not hold the
				// download back for WiFi: a ~30MB model is the point of asking
				translator.downloadModelIfNeeded()
						.addOnSuccessListener(unused -> runTranslation(translator))
						.addOnFailureListener(this::failed);
				return;
			}
			finish();
		}

		/**
		 * The Dart side offers to download the missing model and then asks again
		 * with interactive == true, which is the step this starts.
		 */
		void checkModelsDownloaded(Translator translator, String source, List<String> required, int index) {
			if (index == required.size()) {
				runTranslation(translator);
				return;
			}
			final RemoteModelManager modelManager = RemoteModelManager.getInstance();
			final Task<Boolean> check = modelManager.isModelDownloaded(new TranslateRemoteModel.Builder(required.get(index)).build());
			check.addOnSuccessListener(downloaded -> {
						if (!downloaded) {
							// The best source language is the one worth naming in
							// the prompt, so only the first missing model counts
							if (missingModelLanguage == null) {
								missingModelLanguage = source;
							}
							attemptNextSourceLanguage();
							return;
						}
						checkModelsDownloaded(translator, source, required, index + 1);
					})
					.addOnFailureListener(this::failed);
		}

		void runTranslation(Translator translator) {
			final ShieldedTags shielded = shieldTagNames(text);
			translator.translate(shielded.text)
					.addOnSuccessListener(translated -> {
						// An empty answer would blank out the post
						if (translated == null || translated.trim().isEmpty()) {
							Log.w("translation", "ML Kit answered with nothing");
							completeWithError("UNSUPPORTED", "ML Kit answered with nothing", null);
							return;
						}
						if (!tagsSurvived(shielded.text, translated)) {
							// The tags are the links and the quote references, so
							// a translation that lost one would delete it. The
							// text is left whole for the translator rather than
							// translated around the tags, and a request it cannot
							// answer goes back to the caller's HTTP backend
							Log.w("translation", "ML Kit lost the HTML tags");
							completeWithError("UNSUPPORTED", "ML Kit lost the HTML tags", null);
							return;
						}
						complete(restoreTagNames(translated, shielded.originals));
					})
					.addOnFailureListener(this::failed);
		}

		void failed(Exception e) {
			didFail = true;
			if (e instanceof MlKitException && ((MlKitException) e).getErrorCode() == MlKitException.CANCELLED) {
				failureCode = "CANCELLED";
			}
			else {
				failureCode = "TRANSLATION_FAILED";
			}
			failure = e.getMessage();
			Log.w("translation", "Translation failed", e);
			// Another source language might work, so this is only reported if
			// none of them does
			attemptNextSourceLanguage();
		}

		void finish() {
			if (missingModelLanguage != null) {
				// The Dart side turns this into a "download this language" prompt
				// and asks again with interactive == true
				completeWithError("INTERACTION_NEEDED", "Language download required", missingModelLanguage);
			}
			else if (didFail) {
				completeWithError(failureCode, failure, null);
			}
			else {
				// Nothing here can translate it, so let the caller use its HTTP
				// backend: the detected language is one this engine has no model
				// for, or the pair is not supported at all
				completeWithError("UNSUPPORTED", "No translatable source language", null);
			}
		}

		void complete(String value) {
			if (completed) {
				return;
			}
			completed = true;
			result.success(value);
		}

		void completeWithError(String code, String message, Object details) {
			if (completed) {
				return;
			}
			completed = true;
			result.error(code, message, details);
		}
	}
}
