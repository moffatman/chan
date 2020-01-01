package main

import (
	"github.com/go-flutter-desktop/go-flutter"
	"github.com/go-flutter-desktop/plugins/video_player"
	"github.com/go-flutter-desktop/plugins/path_provider"
)

var options = []flutter.Option{
	flutter.WindowInitialDimensions(640, 640),
	flutter.AddPlugin(&video_player.VideoPlayerPlugin{}),
	flutter.AddPlugin(&path_provider.PathProviderPlugin{
		VendorName:      "moffatman",
		ApplicationName: "chan",
	}),
}
