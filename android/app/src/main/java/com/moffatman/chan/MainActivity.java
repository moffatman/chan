package com.moffatman.chan;

import android.app.NotificationManager;
import android.content.ClipData;
import android.content.ClipboardManager;
import android.content.Context;
import android.content.Intent;
import android.content.UriPermission;
import android.database.Cursor;
import android.media.AudioDeviceInfo;
import android.media.AudioManager;
import android.net.Uri;
import android.os.Environment;
import android.os.ParcelFileDescriptor;
import android.provider.DocumentsContract;
import android.webkit.MimeTypeMap;
import android.util.Log;
import android.webkit.WebSettings;

import androidx.activity.result.ActivityResultLauncher;
import androidx.activity.result.contract.ActivityResultContracts.CreateDocument;
import androidx.activity.result.contract.ActivityResultContracts.OpenDocumentTree;
import androidx.annotation.NonNull;
import androidx.documentfile.provider.DocumentFile;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.util.Arrays;
import java.util.List;

import io.flutter.embedding.android.FlutterFragmentActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.StandardMethodCodec;

public class MainActivity extends FlutterFragmentActivity {
    private static final String STORAGE_CHANNEL = "com.moffatman.chan/storage";
    private static final String NOTIFICATIONS_CHANNEL = "com.moffatman.chan/notifications";
    private static final String CLIPBOARD_CHANNEL = "com.moffatman.chan/clipboard";

    private static final String AUDIO_CHANNEL = "com.moffatman.chan/audio";
    private static final String USER_AGENT_CHANNEL = "com.moffatman.chan/userAgent";
    private MethodChannel.Result folderResult;

    private MethodChannel.Result saveFileAsResult;
    private String newDocumentSourcePath;

    private DocumentFile fastFindFile(DocumentFile parent, String name) {
        try {
            try (Cursor cursor = getContentResolver().query(DocumentsContract.buildChildDocumentsUriUsingTree(
                    parent.getUri(),
                    DocumentsContract.getDocumentId(parent.getUri())
            ), new String[]{
                    DocumentsContract.Document.COLUMN_DOCUMENT_ID,
                    DocumentsContract.Document.COLUMN_DISPLAY_NAME
            }, null, null, null)) {
                while (cursor.moveToNext()) {
                    if (name.equals(cursor.getString(1))) {
                        return DocumentFile.fromTreeUri(getApplicationContext(), DocumentsContract.buildDocumentUriUsingTree(parent.getUri(), cursor.getString(0)));
                    }
                }
            }
        }
        catch (Exception e) {
            Log.w("fastFindFile", "Got exception", e);
        }
        return null;
    }

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        ActivityResultLauncher<Uri> getFolder = registerForActivityResult(new OpenDocumentTree() {
            @Override
            @NonNull
            public Intent createIntent(@NonNull Context context, Uri input) {
                Intent intent = super.createIntent(context, input);
                intent.addFlags(
                    Intent.FLAG_GRANT_READ_URI_PERMISSION |
                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION |
                    Intent.FLAG_GRANT_PREFIX_URI_PERMISSION |
                    Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION
                );
                return intent;
            }
        }, uri -> {
            if (uri != null) {
                getContentResolver().takePersistableUriPermission(
                    uri,
                    Intent.FLAG_GRANT_READ_URI_PERMISSION | Intent.FLAG_GRANT_WRITE_URI_PERMISSION
                );
                if (folderResult != null) {
                    folderResult.success(uri.toString());
                    return;
                }
            }
            if (folderResult != null) {
                folderResult.success(null);
            }
        });
        ActivityResultLauncher<String> newDocument = registerForActivityResult(new CreateDocument("*/*") {
            @Override
            @NonNull
            public Intent createIntent(@NonNull Context context, String input) {
                Intent intent = super.createIntent(context, input);
                if (input.endsWith(".png")) {
                    intent.setType("image/png");
                }
                else if (input.endsWith(".jpg") || input.endsWith(".jpeg")) {
                    intent.setType("image/jpeg");
                }
                else if (input.endsWith(".gif")) {
                    intent.setType("image/gif");
                }
                else if (input.endsWith(".mp4")) {
                    intent.setType("video/mp4");
                }
                else if (input.endsWith(".webm")) {
                    intent.setType("video/webm");
                }
                else if (input.endsWith(".mp3")) {
                    intent.setType("audio/mp3");
                }
                return intent;
            }
        }, uri -> {
            if (saveFileAsResult == null) {
                Log.e("newDocument", "saveFileAsResult was null!");
                return;
            }
            if (uri == null) {
                saveFileAsResult.success(null);
                return;
            }
            try {
                ParcelFileDescriptor destinationFileDescriptor = getContentResolver().openFileDescriptor(uri, "w");
                File sourceFile = new File(newDocumentSourcePath);
                FileOutputStream destinationWriteStream = new FileOutputStream(destinationFileDescriptor.getFileDescriptor());
                FileInputStream sourceReadStream = new FileInputStream(sourceFile);
                byte[] buffer = new byte[4096];
                int len;
                while ((len = sourceReadStream.read(buffer, 0, 4096)) > 0) {
                    destinationWriteStream.write(buffer, 0, len);
                }
                destinationWriteStream.close();
                destinationFileDescriptor.close();
                sourceReadStream.close();
                saveFileAsResult.success(uri.toString());
            }
            catch (IOException e) {
                saveFileAsResult.error("FileNotFound", e.getMessage(), null);
            }
        });
        super.configureFlutterEngine(flutterEngine);
        BinaryMessenger.TaskQueue storageTaskQueue = flutterEngine.getDartExecutor().getBinaryMessenger().makeBackgroundTaskQueue();
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), STORAGE_CHANNEL, StandardMethodCodec.INSTANCE, storageTaskQueue).setMethodCallHandler(
                (call, result) -> {
                    if (call.method.equals("pickDirectory")) {
                        System.out.println(getContentResolver().getPersistedUriPermissions());
                        this.folderResult = result;
                        getFolder.launch(Uri.fromFile(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOCUMENTS)));
                    }
                    else if (call.method.equals("saveFile")) {
                        try {
                            String sourcePath = call.argument("sourcePath");
                            String destinationDir = call.argument("destinationDir");
                            List<String> destinationSubfolders = call.argument("destinationSubfolders");
                            String destinationName = call.argument("destinationName");
                            Uri destination = Uri.parse(destinationDir);
                            boolean sufficientPermission = false;
                            for (UriPermission permission : getContentResolver().getPersistedUriPermissions()) {
                                if (permission.getUri().equals(destination)) {
                                    sufficientPermission = permission.isWritePermission() && permission.isReadPermission();
                                }
                            }
                            if (!sufficientPermission) {
                                result.error("InsufficientPermission", "Permissions not enough or have expired", null);
                                return;
                            }
                            DocumentFile dir = DocumentFile.fromTreeUri(this, destination);
                            if (!dir.exists()) {
                                result.error("DirectoryNotFound", "Supplied directory does not exist", null);
                                return;
                            }
                            for (String subdirName : destinationSubfolders) {
                                DocumentFile subdir = fastFindFile(dir, subdirName);
                                if (subdir != null && subdir.isDirectory()) {
                                    dir = subdir;
                                }
                                else {
                                    dir = dir.createDirectory(subdirName);
                                }
                            }
                            String filename = destinationName;
                            int duplicateNumber = 0;
                            DocumentFile existing;
                            do {
                                if (duplicateNumber > 0) {
                                    int dotPos = destinationName.lastIndexOf('.');
                                    if (dotPos == -1) {
                                        result.error("FilenameProblem", "Supplied filename has no file extension", null);
                                        return;
                                    }
                                    filename = String.format("%s (%d)%s", destinationName.substring(0, dotPos), duplicateNumber, destinationName.substring(dotPos));
                                }
                                existing = fastFindFile(dir, filename);
                                duplicateNumber++;
                            } while (existing != null);
                            DocumentFile file = dir.createFile(MimeTypeMap.getFileExtensionFromUrl(filename), filename);
                            ParcelFileDescriptor destinationFileDescriptor = getContentResolver().openFileDescriptor(file.getUri(), "w");
                            File sourceFile = new File(sourcePath);
                            FileOutputStream destinationWriteStream = new FileOutputStream(destinationFileDescriptor.getFileDescriptor());
                            FileInputStream sourceReadStream = new FileInputStream(sourceFile);
                            byte[] buffer = new byte[4096];
                            int len;
                            while ((len = sourceReadStream.read(buffer, 0, 4096)) > 0) {
                                destinationWriteStream.write(buffer, 0, len);
                            }
                            destinationWriteStream.close();
                            destinationFileDescriptor.close();
                            sourceReadStream.close();
                            result.success(filename);
                        }
                        catch (FileNotFoundException e) {
                            result.error("FileNotFound", e.getMessage(), null);
                        }
                        catch (IOException e) {
                            result.error("IOException", e.getMessage(), null);
                        }
                    }
                    else if (call.method.equals("saveFileAs")) {
                        this.saveFileAsResult = result;
                        this.newDocumentSourcePath = call.argument("sourcePath");
                        String destinationName = call.argument("destinationName");
                        newDocument.launch(destinationName);
                    }
                    else {
                        result.notImplemented();
                    }
                }
        );
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), NOTIFICATIONS_CHANNEL).setMethodCallHandler(
                (call, result) -> {
                    if (call.method.equals("clearNotificationsWithProperties")) {
                        // Seems to be no way to find the notifications after they are posted
                        // Unfortunately have to cancel everything
                        NotificationManager nm = (NotificationManager)getSystemService(Context.NOTIFICATION_SERVICE);
                        nm.cancelAll();
                        result.success(null);
                    }
                    else {
                        result.notImplemented();
                    }
                }
        );
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CLIPBOARD_CHANNEL).setMethodCallHandler(
                (call, result) -> {
                    try {
                        if (call.method.equals("doesClipboardContainImage")) {
                            ClipboardManager cm = (ClipboardManager) getSystemService(Context.CLIPBOARD_SERVICE);
                            ClipData primaryClip = cm.getPrimaryClip();
                            if (primaryClip != null) {
                                ClipData.Item item = primaryClip.getItemAt(0);
                                if (item.getUri() != null) {
                                    String[] parts = item.getUri().toString().split("\\.");
                                    String ext = parts[parts.length - 1];
                                    result.success(ext.equals("jpg") || ext.equals("jpeg") || ext.equals("png") || ext.equals("gif"));
                                    return;
                                }
                            }
                            result.success(null);
                        } else if (call.method.equals("getClipboardImage")) {
                            ClipboardManager cm = (ClipboardManager) getSystemService(Context.CLIPBOARD_SERVICE);
                            ClipData primaryClip = cm.getPrimaryClip();
                            if (primaryClip != null) {
                                ClipData.Item item = primaryClip.getItemAt(0);
                                if (item.getUri() != null) {
                                    try {
                                        InputStream stream = getContentResolver().openInputStream(item.getUri());
                                        byte[] data = new byte[stream.available()];
                                        stream.read(data);
                                        result.success(data);
                                    } catch (IOException e) {
                                        result.error("FILE_ERROR", "Could not open file for reading", null);
                                    }
                                    return;
                                }
                            }
                            result.success(null);
                        } else {
                            result.notImplemented();
                        }
                    }
                    catch (Exception e) {
                        result.error("JAVA_EXCEPTION", e.getMessage(), null);
                    }
                }
        );
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), AUDIO_CHANNEL).setMethodCallHandler(
                (call, result) -> {
                    try {
                        if (call.method.equals("areHeadphonesPluggedIn")) {
                            AudioManager audioManager = (AudioManager)getSystemService(Context.AUDIO_SERVICE);
                            result.success(Arrays.stream(audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS)).anyMatch((device) -> {
                                switch (device.getType()) {
                                    case AudioDeviceInfo.TYPE_WIRED_HEADSET:
                                    case AudioDeviceInfo.TYPE_WIRED_HEADPHONES:
                                    case AudioDeviceInfo.TYPE_BLUETOOTH_A2DP:
                                    case AudioDeviceInfo.TYPE_BLUETOOTH_SCO:
                                        return true;
                                }
                                return false;
                            }));
                        } else {
                            result.notImplemented();
                        }
                    }
                    catch (Exception e) {
                        result.error("JAVA_EXCEPTION", e.getMessage(), null);
                    }
                }
        );
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), USER_AGENT_CHANNEL).setMethodCallHandler(
                (call, result) -> {
                    try {
                        if (call.method.equals("getDefaultUserAgent")) {
                            result.success(WebSettings.getDefaultUserAgent(getApplicationContext()));
                        } else {
                            result.notImplemented();
                        }
                    }
                    catch (Exception e) {
                        result.error("JAVA_EXCEPTION", e.getMessage(), null);
                    }
                }
        );
    }
}
