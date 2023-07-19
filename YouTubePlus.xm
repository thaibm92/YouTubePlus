#import "Header.h"

NSBundle *YouTubePlusBundle() {
    static NSBundle *bundle = nil;
    static dispatch_once_t onceToken;
 	dispatch_once(&onceToken, ^{
        NSString *tweakBundlePath = [[NSBundle mainBundle] pathForResource:@"YouTubePlus" ofType:@"bundle"];
        if (tweakBundlePath)
            bundle = [NSBundle bundleWithPath:tweakBundlePath];
        else
            bundle = [NSBundle bundleWithPath:ROOT_PATH_NS(@"/Library/Application Support/YouTubePlus.bundle")];
    });
    return bundle;
}
NSBundle *tweakBundle = YouTubePlusBundle();

// Keychain fix
static NSString *accessGroupID() {
    NSDictionary *query = [NSDictionary dictionaryWithObjectsAndKeys:
                           (__bridge NSString *)kSecClassGenericPassword, (__bridge NSString *)kSecClass,
                           @"bundleSeedID", kSecAttrAccount,
                           @"", kSecAttrService,
                           (id)kCFBooleanTrue, kSecReturnAttributes,
                           nil];
    CFDictionaryRef result = nil;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, (CFTypeRef *)&result);
    if (status == errSecItemNotFound)
        status = SecItemAdd((__bridge CFDictionaryRef)query, (CFTypeRef *)&result);
        if (status != errSecSuccess)
            return nil;
    NSString *accessGroup = [(__bridge NSDictionary *)result objectForKey:(__bridge NSString *)kSecAttrAccessGroup];

    return accessGroup;
}

//
static BOOL IsEnabled(NSString *key) {
    return [[NSUserDefaults standardUserDefaults] boolForKey:key];
}

%hook YTAppDelegate
- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary<UIApplicationLaunchOptionsKey, id> *)launchOptions {
    BOOL didFinishLaunching = %orig;

    if (IsEnabled(@"flex_enabled")) {
        [[FLEXManager sharedManager] showExplorer];
    }

    return didFinishLaunching;
}
- (void)appWillResignActive:(id)arg1 {
    %orig;
        if (IsEnabled(@"flex_enabled")) {
        [[FLEXManager sharedManager] showExplorer];
    }
}
%end

# pragma mark - Tweaks
// Skips content warning before playing *some videos - @PoomSmart
%hook YTPlayabilityResolutionUserActionUIController
- (void)showConfirmAlert { [self confirmAlertDidPressConfirm]; }
%end

// YTMiniPlayerEnabler: https://github.com/level3tjg/YTMiniplayerEnabler/
%hook YTWatchMiniBarViewController
- (void)updateMiniBarPlayerStateFromRenderer {
    if (IsEnabled(@"ytMiniPlayer_enabled")) {}
    else { return %orig; }
}
%end

# pragma mark - Notification Button && iSponsorBlock Button
%hook YTRightNavigationButtons
- (void)layoutSubviews {
    %orig;
    if (IsEnabled(@"hideNotificationButton_enabled")) {
        self.notificationButton.hidden = YES;
    }
    if (IsEnabled(@"hideSponsorBlockButton_enabled")) { 
        self.sponsorBlockButton.hidden = YES;
    }
}
%end

// Hide Cast Button
%group gHideCastButton
%hook MDXPlaybackRouteButtonController
- (BOOL)isPersistentCastIconEnabled { return NO; }
- (void)updateRouteButton:(id)arg1 {} // hide Cast button in video controls overlay
- (void)updateAllRouteButtons {} // hide Cast button in Nav bar
%end

%hook YTSettings
- (void)setDisableMDXDeviceDiscovery:(BOOL)arg1 { %orig(YES); }
%end
%end

// Hide CC / Autoplay switch / Disable the right panel in fullscreen mode
%hook YTMainAppControlsOverlayView
- (void)setClosedCaptionsOrSubtitlesButtonAvailable:(BOOL)arg1 { // hide CC button
    return IsEnabled(@"hideCC_enabled") ? %orig(NO) : %orig;
}
- (void)setAutoplaySwitchButtonRenderer:(id)arg1 { // hide Autoplay
    if (IsEnabled(@"hideAutoplaySwitch_enabled")) {}
    else { return %orig; }
}
- (void)setShareButtonAvailable:(BOOL)arg1 {
    if (IsEnabled(@"enableShareButton_enabled")) {
        %orig(YES);
    } else {
        %orig(NO);
    }
}
- (void)setAddToButtonAvailable:(BOOL)arg1 {
    if (IsEnabled(@"enableSaveToButton_enabled")) {
        %orig(YES);
    } else {
        %orig(NO);
    }
}
%end

%hook YTColdConfig
- (BOOL)isLandscapeEngagementPanelEnabled {
    return IsEnabled(@"hideRightPanel_enabled") ? NO : %orig;
}
%end

// Hide Next & Previous button
%group gHidePreviousAndNextButton
%hook YTColdConfig
- (BOOL)removeNextPaddleForSingletonVideos { return YES; }
- (BOOL)removePreviousPaddleForSingletonVideos { return YES; }
%end
%end

%group gHideOverlayDarkBackground
%hook YTMainAppVideoPlayerOverlayView
- (void)setBackgroundVisible:(BOOL)arg1 {
    %orig(NO);
}
%end
%end

%group gHideVideoPlayerShadowOverlayButtons
%hook YTMainAppControlsOverlayView
- (void)layoutSubviews {
	%orig();
    MSHookIvar<YTTransportControlsButtonView *>(self, "_previousButtonView").backgroundColor = nil;
    MSHookIvar<YTTransportControlsButtonView *>(self, "_nextButtonView").backgroundColor = nil;
    MSHookIvar<YTTransportControlsButtonView *>(self, "_seekBackwardAccessibilityButtonView").backgroundColor = nil;
    MSHookIvar<YTTransportControlsButtonView *>(self, "_seekForwardAccessibilityButtonView").backgroundColor = nil;
    MSHookIvar<YTPlaybackButton *>(self, "_playPauseButton").backgroundColor = nil;
}
%end
%end

// A/B flags
%hook YTColdConfig 
- (BOOL)respectDeviceCaptionSetting { return NO; } // YouRememberCaption: https://poomsmart.github.io/repo/depictions/youremembercaption.html
- (BOOL)isLandscapeEngagementPanelSwipeRightToDismissEnabled { return YES; } // Swipe right to dismiss the right panel in fullscreen mode
- (BOOL)commercePlatformClientEnablePopupWebviewInWebviewDialogController { return NO;} // Disable In-App Website in the App
%end

// Hide Upgrade Dialog
%hook YTGlobalConfig
- (BOOL)shouldBlockUpgradeDialog { return YES;}
- (BOOL)shouldForceUpgrade { return NO;}
- (BOOL)shouldShowUpgrade { return NO;}
- (BOOL)shouldShowUpgradeDialog { return NO;}
%end

// No YouTube Ads
%hook YTDataUtils
+ (id)spamSignalsDictionary { return nil; }
+ (id)spamSignalsDictionaryWithoutIDFA { return nil; }
%end

%hook YTHotConfig
- (BOOL)disableAfmaIdfaCollection { return NO; }
%end

// Hide YouTube search ads
%hook YTIElementRenderer
- (NSData *)elementData {
    if (self.hasCompatibilityOptions && self.compatibilityOptions.hasAdLoggingData)
        return nil;
    return %orig;
}
%end

BOOL isAd(id node) {
    if ([node isKindOfClass:NSClassFromString(@"YTVideoWithContextNode")]
        && [node respondsToSelector:@selector(parentResponder)]
        && [[(YTVideoWithContextNode *)node parentResponder] isKindOfClass:NSClassFromString(@"YTAdVideoElementsCellController")])
        return YES;
    if ([node isKindOfClass:NSClassFromString(@"ELMCellNode")]) {
        NSString *description = [[[node controller] owningComponent] description];
        if ([description containsString:@"brand_promo"]
            || [description containsString:@"statement_banner"]
            || [description containsString:@"product_carousel"]
            || [description containsString:@"product_engagement_panel"]
            || [description containsString:@"product_item"]
            || [description containsString:@"text_search_ad"]
            || [description containsString:@"text_image_button_layout"]
            || [description containsString:@"carousel_headered_layout"]
            || [description containsString:@"square_image_layout"] // install app ad
            || [description containsString:@"feed_ad_metadata"])
            return YES;
    }
    return NO;
}

%hook YTAsyncCollectionView
- (id)collectionView:(id)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    _ASCollectionViewCell *cell = %orig;
    if ([cell isKindOfClass:NSClassFromString(@"_ASCollectionViewCell")]
        && [cell respondsToSelector:@selector(node)]
        && isAd([cell node]))
            [self deleteItemsAtIndexPaths:[NSArray arrayWithObject:indexPath]];
    return cell;
}
%end

// Disable Wifi Related Settings - @arichorn
%group gDisableWifiRelatedSettings
%hook YTSettingsSectionItemManager
- (void)updatePremiumEarlyAccessSectionWithEntry:(id)arg1 {} // Try New Features
- (void)updateAutoplaySectionWithEntry:(id)arg1 {} // Autoplay
- (void)updateNotificationSectionWithEntry:(id)arg1 {} // Notifications
- (void)updateHistorySectionWithEntry:(id)arg1 {} // History
- (void)updatePrivacySectionWithEntry:(id)arg1 {} // Privacy
- (void)updateHistoryAndPrivacySectionWithEntry:(id)arg1 {} // History & Privacy
- (void)updateLiveChatSectionWithEntry:(id)arg1 {} // Live Chat
%end
%end

// NOYTPremium - https://github.com/PoomSmart/NoYTPremium/
%hook YTCommerceEventGroupHandler
- (void)addEventHandlers {}
%end

%hook YTInterstitialPromoEventGroupHandler
- (void)addEventHandlers {}
%end

%hook YTPromosheetEventGroupHandler
- (void)addEventHandlers {}
%end

%hook YTPromoThrottleController
- (BOOL)canShowThrottledPromo { return NO; }
- (BOOL)canShowThrottledPromoWithFrequencyCap:(id)arg1 { return NO; }
- (BOOL)canShowThrottledPromoWithFrequencyCaps:(id)arg1 { return NO; }
%end

%hook YTIShowFullscreenInterstitialCommand
- (BOOL)shouldThrottleInterstitial { return YES; }
%end

%hook YTSurveyController
- (void)showSurveyWithRenderer:(id)arg1 surveyParentResponder:(id)arg2 {}
%end

// YTShortsProgress - @PoomSmart - https://github.com/PoomSmart/YTShortsProgress
%hook YTReelPlayerViewController
- (BOOL)shouldEnablePlayerBar { return YES; }
- (BOOL)shouldAlwaysEnablePlayerBar { return YES; }
- (BOOL)shouldEnablePlayerBarOnlyOnPause { return NO; }
%end

%hook YTReelPlayerViewControllerSub
- (BOOL)shouldEnablePlayerBar { return YES; }
- (BOOL)shouldAlwaysEnablePlayerBar { return YES; }
- (BOOL)shouldEnablePlayerBarOnlyOnPause { return NO; }
%end

%hook YTColdConfig
- (BOOL)iosEnableVideoPlayerScrubber { return YES; }
- (BOOL)mobileShortsTabInlined { return YES; }
%end

%hook YTHotConfig
- (BOOL)enablePlayerBarForVerticalVideoWhenControlsHiddenInFullscreen { return YES; }
%end

// YTNoModernUI - @arichorn
%group gYTNoModernUI
%hook YTVersionUtils // YTNoModernUI Version
+ (NSString *)appVersion { return @"17.11.2"; } // Spoofs YouTube to v17.11.2
%end

%hook YTInlinePlayerBarContainerView // Red Progress Bar - YTNoModernUI
- (id)quietProgressBarColor {
    return [UIColor redColor];
}
%end

%hook YTSegmentableInlinePlayerBarView // Old Buffer Bar - YTNoModernUI
- (void)setBufferedProgressBarColor:(id)arg1 {
     [UIColor colorWithRed:0.65 green:0.65 blue:0.65 alpha:0.60];
}
%end

%hook YTQTMButton
- (BOOL)buttonModernizationEnabled { return NO; }
%end

%hook YTSearchBarView
- (BOOL)_roundedSearchBarEnabled { return NO; }
%end

%hook YTColdConfig
// Disable Modern Content - YTNoModernUI
- (BOOL)creatorClientConfigEnableStudioModernizedMdeThumbnailPickerForClient { return NO; }
- (BOOL)cxClientEnableModernizedActionSheet { return NO; }
- (BOOL)enableClientShortsSheetsModernization { return NO; }
- (BOOL)enableTimestampModernizationForNative { return NO; }
- (BOOL)mainAppCoreClientIosEnableModernOssPage { return NO; }
- (BOOL)modernizeElementsTextColor { return NO; }
- (BOOL)modernizeElementsBgColor { return NO; }
- (BOOL)modernizeCollectionLockups { return NO; }
- (BOOL)uiSystemsClientGlobalConfigEnableEpUxUpdates { return NO; }
- (BOOL)uiSystemsClientGlobalConfigEnableModernButtonsForNative { return NO; }
- (BOOL)uiSystemsClientGlobalConfigEnableModernButtonsForNativeLongTail { return NO; }
- (BOOL)uiSystemsClientGlobalConfigEnableModernTabsForNative { return NO; }
- (BOOL)uiSystemsClientGlobalConfigIosEnableSnackbarModernization { return NO; }
// Disable Rounded Content - YTNoModernUI
- (BOOL)iosEnableRoundedSearchBar { return NO; }
- (BOOL)enableIosRoundedSearchBar { return NO; }
- (BOOL)enableIosSearchBar { return NO; }
- (BOOL)iosDownloadsPageRoundedThumbs { return NO; }
- (BOOL)iosRoundedSearchBarSuggestZeroPadding { return NO; }
- (BOOL)uiSystemsClientGlobalConfigEnableRoundedThumbnailsForNative { return NO; }
- (BOOL)uiSystemsClientGlobalConfigEnableRoundedThumbnailsForNativeLongTail { return NO; }
- (BOOL)uiSystemsClientGlobalConfigEnableRoundedTimestampForNative { return NO; }
- (BOOL)uiSystemsClientGlobalConfigEnableRoundedDialogForNative { return NO; }
// Disable Darker Dark Mode - YTNoModernUI
- (BOOL)enableDarkerDarkMode { return NO; }
- (BOOL)useDarkerPaletteBgColorForElements { return NO; }
- (BOOL)useDarkerPaletteTextColorForElements { return NO; }
- (BOOL)uiSystemsClientGlobalConfigUseDarkerPaletteTextColorForNative { return NO; }
- (BOOL)uiSystemsClientGlobalConfigUseDarkerPaletteBgColorForNative { return NO; }
// Disable Ambient Mode - YTNoModernUI
- (BOOL)disableCinematicForLowPowerMode { return NO; }
- (BOOL)enableCinematicContainer { return NO; }
- (BOOL)enableCinematicContainerOnClient { return NO; }
- (BOOL)enableCinematicContainerOnTablet { return NO; }
- (BOOL)iosCinematicContainerClientImprovement { return NO; }
- (BOOL)iosEnableGhostCardInlineTitleCinematicContainerFix { return NO; }
- (BOOL)iosUseFineScrubberMosaicStoreForCinematic { return NO; }
- (BOOL)mainAppCoreClientEnableClientCinematicPlaylists { return NO; }
- (BOOL)mainAppCoreClientEnableClientCinematicPlaylistsPostMvp { return NO; }
- (BOOL)mainAppCoreClientEnableClientCinematicTablets { return NO; }
// 16.42.3 Styled YouTube Channel Page Interface - YTNoModernUI
- (BOOL)channelsClientConfigIosChannelNavRestructuring { return NO; }
- (BOOL)channelsClientConfigIosMultiPartChannelHeader { return NO; }
// Disable Optional Content - YTNoModernUI
- (BOOL)elementsClientIosElementsEnableLayoutUpdateForIob { return NO; }
- (BOOL)supportElementsInMenuItemSupportedRenderers { return NO; }
- (BOOL)isNewRadioButtonStyleEnabled { return NO; }
- (BOOL)uiSystemsClientGlobalConfigEnableButtonSentenceCasingForNative { return NO; }
%end

%hook YTHotConfig
- (BOOL)liveChatIosUseModernRotationDetectiom { return NO; } // Disable Modern Content (YTHotConfig)
- (BOOL)iosShouldRepositionChannelBar { return NO; }
- (BOOL)enableElementRendererOnChannelCreation { return NO; }
%end

%hook YTCinematicContainerView
- (void)setHidden:(BOOL)arg1 {
    %orig(YES);
}
%end
%end

// Disable Video Player Zoom - @arichorn
%group gDisableVideoPlayerZoom
%hook YTColdConfig
- (BOOL)enableFreeZoomHaptics { return NO; }
- (BOOL)enableFreeZoomInPotraitOrientation { return NO; }
- (BOOL)isVideoZoomEnabled { return NO; }
- (BOOL)uiSystemsClientGlobalConfigEnableDisplayZoomMenuBugFix { return NO; }
- (BOOL)videoZoomFreeZoomEnabledGlobalConfig { return NO; }
- (BOOL)videoZoomFreeZoomIndicatorPersistentGlobalConfig { return NO; }
- (BOOL)videoZoomFreeZoomIndicatorTopGlobalConfig { return NO; }
- (BOOL)deprecateTabletPinchFullscreenGestures { return NO; } // <-- this is an iPad Exclusive Flag
%end
%end

// Hide YouTube Heatwaves in Video Player (YouTube v17.19.2-present) - @level3tjg - https://www.reddit.com/r/jailbreak/comments/v29yvk/
%group gHideHeatwaves
%hook YTInlinePlayerBarContainerView
- (BOOL)canShowHeatwave { return NO; }
%end
%end

// Replace Next & Previous button with Fast forward & Rewind button
%group gReplacePreviousAndNextButton
%hook YTColdConfig
- (BOOL)replaceNextPaddleWithFastForwardButtonForSingletonVods { return YES; }
- (BOOL)replacePreviousPaddleWithRewindButtonForSingletonVods { return YES; }
%end
%end

// Hide HUD Messages
%hook YTHUDMessageView
- (id)initWithMessage:(id)arg1 dismissHandler:(id)arg2 {
    return IsEnabled(@"hideHUD_enabled") ? nil : %orig;
}
%end

// YTAutoFullScreen: https://github.com/PoomSmart/YTAutoFullScreen/
%hook YTPlayerViewController
- (void)loadWithPlayerTransition:(id)arg1 playbackConfig:(id)arg2 {
    %orig;
    if (IsEnabled(@"autoFull_enabled"))
        [NSTimer scheduledTimerWithTimeInterval:0.75 target:self selector:@selector(autoFullscreen) userInfo:nil repeats:NO];
}
%new
- (void)autoFullscreen {
    YTWatchController *watchController = [self valueForKey:@"_UIDelegate"];
    [watchController showFullScreen];
}
%end

%hook YTYouThereController
- (BOOL)shouldShowYouTherePrompt { return NO; }
%end

// YTNOCheckLocalNetWork - https://poomsmart.github.io/repo/depictions/ytnochecklocalnetwork.html
%hook YTHotConfig
- (BOOL)isPromptForLocalNetworkPermissionsEnabled { return NO; }
%end

// YTClassicVideoQuality - https://github.com/PoomSmart/YTClassicVideoQuality
%hook YTVideoQualitySwitchControllerFactory
- (id)videoQualitySwitchControllerWithParentResponder:(id)responder {
    Class originalClass = %c(YTVideoQualitySwitchOriginalController);
    return originalClass ? [[originalClass alloc] initWithParentResponder:responder] : %orig;
}
%end

// YTNoHoverCards: https://github.com/level3tjg/YTNoHoverCards
%hook YTCreatorEndscreenView
- (void)setHidden:(BOOL)hidden {
    if (IsEnabled(@"hideHoverCards_enabled"))
        hidden = YES;
    %orig;
}
%end

/// YTNoPaidPromo: https://github.com/PoomSmart/YTNoPaidPromo
%hook YTMainAppVideoPlayerOverlayViewController
- (void)setPaidContentWithPlayerData:(id)data {
    if (IsEnabled(@"hidePaidPromotionCard_enabled")) {}
    else { return %orig; }
}
- (void)playerOverlayProvider:(YTPlayerOverlayProvider *)provider didInsertPlayerOverlay:(YTPlayerOverlay *)overlay {
    if ([[overlay overlayIdentifier] isEqualToString:@"player_overlay_paid_content"] && IsEnabled(@"hidePaidPromotionCard_enabled")) return;
    %orig;
}
%end

%hook YTInlineMutedPlaybackPlayerOverlayViewController
- (void)setPaidContentWithPlayerData:(id)data {
    if (IsEnabled(@"hidePaidPromotionCard_enabled")) {}
    else { return %orig; }
}
%end

// Remove “Play next in queue” from the menu (@PoomSmart)
%hook YTMenuItemVisibilityHandler
- (BOOL)shouldShowServiceItemRenderer:(YTIMenuConditionalServiceItemRenderer *)renderer {
    return renderer.icon.iconType == 251 ? NO : %orig;
}
%end

# pragma mark - IAmYouTube - https://github.com/PoomSmart/IAmYouTube/
%hook YTVersionUtils
+ (NSString *)appName { return YT_NAME; }
+ (NSString *)appID { return YT_BUNDLE_ID; }
%end

%hook GCKBUtils
+ (NSString *)appIdentifier { return YT_BUNDLE_ID; }
%end

%hook GPCDeviceInfo
+ (NSString *)bundleId { return YT_BUNDLE_ID; }
%end

%hook OGLBundle
+ (NSString *)shortAppName { return YT_NAME; }
%end

%hook GVROverlayView
+ (NSString *)appName { return YT_NAME; }
%end

%hook OGLPhenotypeFlagServiceImpl
- (NSString *)bundleId { return YT_BUNDLE_ID; }
%end

%hook APMAEU
+ (BOOL)isFAS { return YES; }
%end

%hook GULAppEnvironmentUtil
+ (BOOL)isFromAppStore { return YES; }
%end

%hook SSOConfiguration
- (id)initWithClientID:(id)clientID supportedAccountServices:(id)supportedAccountServices {
    self = %orig;
    [self setValue:YT_NAME forKey:@"_shortAppName"];
    [self setValue:YT_BUNDLE_ID forKey:@"_applicationIdentifier"];
    return self;
}
%end

%hook NSBundle
- (NSString *)bundleIdentifier {
    NSArray *address = [NSThread callStackReturnAddresses];
    Dl_info info = {0};
    if (dladdr((void *)[address[2] longLongValue], &info) == 0)
        return %orig;
    NSString *path = [NSString stringWithUTF8String:info.dli_fname];
    if ([path hasPrefix:NSBundle.mainBundle.bundlePath])
        return YT_BUNDLE_ID;
    return %orig;
}
- (id)objectForInfoDictionaryKey:(NSString *)key {
    if ([key isEqualToString:@"CFBundleIdentifier"])
        return YT_BUNDLE_ID;
    if ([key isEqualToString:@"CFBundleDisplayName"] || [key isEqualToString:@"CFBundleName"])
        return YT_NAME;
    return %orig;
}
// Fix Google Sign in by @PoomSmart and @level3tjg (qnblackcat/uYouPlus#684)
- (NSDictionary *)infoDictionary {
    NSMutableDictionary *info = %orig.mutableCopy;
    NSString *altBundleIdentifier = info[@"ALTBundleIdentifier"];
    if (altBundleIdentifier) info[@"CFBundleIdentifier"] = altBundleIdentifier;
    return info;
}
%end

// Fix login for YouTube 18.13.2 and higher @BandarHL
%hook SSOKeychainHelper
+ (NSString *)accessGroup {
    return accessGroupID();
}
+ (NSString *)sharedAccessGroup {
    return accessGroupID();
}
%end

// Fix login for YouTube 17.33.2 and higher - @BandarHL
// https://gist.github.com/BandarHL/492d50de46875f9ac7a056aad084ac10
%hook SSOKeychainCore
+ (NSString *)accessGroup {
    return accessGroupID();
}

+ (NSString *)sharedAccessGroup {
    return accessGroupID();
}
%end

// Fix App Group Directory by move it to document directory
%hook NSFileManager
- (NSURL *)containerURLForSecurityApplicationGroupIdentifier:(NSString *)groupIdentifier {
    if (groupIdentifier != nil) {
        NSArray *paths = [[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask];
        NSURL *documentsURL = [paths lastObject];
        return [documentsURL URLByAppendingPathComponent:@"AppGroup"];
    }
    return %orig(groupIdentifier);
}
%end

// YTReExplore: https://github.com/PoomSmart/YTReExplore/
%group gReExplore
static void replaceTab(YTIGuideResponse *response) {
    NSMutableArray <YTIGuideResponseSupportedRenderers *> *renderers = [response itemsArray];
    for (YTIGuideResponseSupportedRenderers *guideRenderers in renderers) {
        YTIPivotBarRenderer *pivotBarRenderer = [guideRenderers pivotBarRenderer];
        NSMutableArray <YTIPivotBarSupportedRenderers *> *items = [pivotBarRenderer itemsArray];
        NSUInteger shortIndex = [items indexOfObjectPassingTest:^BOOL(YTIPivotBarSupportedRenderers *renderers, NSUInteger idx, BOOL *stop) {
            return [[[renderers pivotBarItemRenderer] pivotIdentifier] isEqualToString:@"FEshorts"];
        }];
        if (shortIndex != NSNotFound) {
            [items removeObjectAtIndex:shortIndex];
            NSUInteger exploreIndex = [items indexOfObjectPassingTest:^BOOL(YTIPivotBarSupportedRenderers *renderers, NSUInteger idx, BOOL *stop) {
                return [[[renderers pivotBarItemRenderer] pivotIdentifier] isEqualToString:[%c(YTIBrowseRequest) browseIDForExploreTab]];
            }];
            if (exploreIndex == NSNotFound) {
                YTIPivotBarSupportedRenderers *exploreTab = [%c(YTIPivotBarRenderer) pivotSupportedRenderersWithBrowseId:[%c(YTIBrowseRequest) browseIDForExploreTab] title:@"Explore" iconType:292];
                [items insertObject:exploreTab atIndex:1];
            }
        }
    }
}
%hook YTGuideServiceCoordinator
- (void)handleResponse:(YTIGuideResponse *)response withCompletion:(id)completion {
    replaceTab(response);
    %orig(response, completion);
}
- (void)handleResponse:(YTIGuideResponse *)response error:(id)error completion:(id)completion {
    replaceTab(response);
    %orig(response, error, completion);
}
%end
%end

// BigYTMiniPlayer: https://github.com/Galactic-Dev/BigYTMiniPlayer
%group Main
%hook YTWatchMiniBarView
- (void)setWatchMiniPlayerLayout:(int)arg1 {
    %orig(1);
}
- (int)watchMiniPlayerLayout {
    return 1;
}
- (void)layoutSubviews {
    %orig;
    self.frame = CGRectMake(([UIScreen mainScreen].bounds.size.width - self.frame.size.width), self.frame.origin.y, self.frame.size.width, self.frame.size.height);
}
%end

%hook YTMainAppVideoPlayerOverlayView
- (BOOL)isUserInteractionEnabled {
    if([[self _viewControllerForAncestor].parentViewController.parentViewController isKindOfClass:%c(YTWatchMiniBarViewController)]) {
        return NO;
    }
    return %orig;
}
%end
%end

// Hide YouTube annoying shorts banner in Home page & search page? - @MiRO92 - YTNoShorts: https://github.com/MiRO92/YTNoShorts
%group gHideShorts
%hook YTAsyncCollectionView
- (id)cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    UICollectionViewCell *cell = %orig;

    if ([cell isKindOfClass:objc_lookUpClass("_ASCollectionViewCell")]) {
        _ASCollectionViewCell *cell = %orig;
        if ([cell respondsToSelector:@selector(node)]) {
            NSString *idToRemove = [[cell node] accessibilityIdentifier];
            if ([idToRemove isEqualToString:@"eml.shorts-grid"] || [idToRemove isEqualToString:@"eml.shorts-shelf"]) {
                [self removeCellsAtIndexPath:indexPath];
            }
        }
    } else if ([cell isKindOfClass:objc_lookUpClass("YTReelShelfCell")]) {
        [self removeCellsAtIndexPath:indexPath];
    }
    return %orig;
}

%new
- (void)removeCellsAtIndexPath:(NSIndexPath *)indexPath {
    [self deleteItemsAtIndexPaths:@[indexPath]];
}
%end
%end

// YTSpeed - https://github.com/Lyvendia/YTSpeed
%group gYTSpeed
%hook YTVarispeedSwitchController
- (id)init {
	id result = %orig;

	const int size = 17;
	float speeds[] = {0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.25, 2.5, 2.75, 3.0, 3.25, 3.5, 3.75, 4.0, 5.0};
	id varispeedSwitchControllerOptions[size];

	for (int i = 0; i < size; ++i) {
		id title = [NSString stringWithFormat:@"%.2fx", speeds[i]];
		varispeedSwitchControllerOptions[i] = [[%c(YTVarispeedSwitchControllerOption) alloc] initWithTitle:title rate:speeds[i]];
	}

	NSUInteger count = sizeof(varispeedSwitchControllerOptions) / sizeof(id);
	NSArray *varispeedArray = [NSArray arrayWithObjects:varispeedSwitchControllerOptions count:count];
	MSHookIvar<NSArray *>(self, "_options") = varispeedArray;

	return result;
}
%end

%hook MLHAMQueuePlayer
- (void)setRate:(float)rate {
    MSHookIvar<float>(self, "_rate") = rate;
	MSHookIvar<float>(self, "_preferredRate") = rate;

	id player = MSHookIvar<HAMPlayerInternal *>(self, "_player");
	[player setRate: rate];

	id stickySettings = MSHookIvar<MLPlayerStickySettings *>(self, "_stickySettings");
	[stickySettings setRate: rate];

	[self.playerEventCenter broadcastRateChange: rate];

	YTSingleVideoController *singleVideoController = self.delegate;
	[singleVideoController playerRateDidChange: rate];
}
%end 

%hook YTPlayerViewController
%property (nonatomic, assign) float playbackRate;
- (void)singleVideo:(id)video playbackRateDidChange:(float)rate {
	%orig;
}
%end
%end

// Disable snap to chapter
%hook YTSegmentableInlinePlayerBarView
- (void)didMoveToWindow {
    %orig;
    if (IsEnabled(@"snapToChapter_enabled")) {
        self.enableSnapToChapter = NO;
    }
}
%end

// Disable Pinch to zoom
%hook YTColdConfig
- (BOOL)videoZoomFreeZoomEnabledGlobalConfig {
    return IsEnabled(@"pinchToZoom_enabled") ? NO : %orig;
}
%end

// YTStockVolumeHUD - https://github.com/lilacvibes/YTStockVolumeHUD
%group gStockVolumeHUD
%hook YTVolumeBarView
- (void)volumeChanged:(id)arg1 {
	%orig(nil);
}
%end

%hook UIApplication 
- (void)setSystemVolumeHUDEnabled:(BOOL)arg1 forAudioCategory:(id)arg2 {
	%orig(true, arg2);
}
%end
%end

// Hide Watermark
%hook YTAnnotationsViewController
- (void)loadFeaturedChannelWatermark {
    if (IsEnabled(@"hideChannelWatermark_enabled")) {}
    else { return %orig; }
}
%end

// Bring back the Red Progress Bar and Gray Buffer Progress - @dayanch96
%group gRedProgressBar
%hook YTInlinePlayerBarContainerView
- (id)quietProgressBarColor {
    return [UIColor redColor];
}
%end

%hook YTSegmentableInlinePlayerBarView
- (void)setBufferedProgressBarColor:(id)arg1 {
     [UIColor colorWithRed:1.00 green:1.00 blue:1.00 alpha:0.90];
}
%end
%end

// Disable double tap to skip
%hook YTMainAppVideoPlayerOverlayViewController
- (BOOL)allowDoubleTapToSeekGestureRecognizer {
     return IsEnabled(@"disableDoubleTapToSkip_enabled") ? NO : %orig;
}
%end

// Hide YouTube Logo
%group gHideYouTubeLogo
%hook YTHeaderLogoController
- (YTHeaderLogoController *)init {
    return NULL;
}
%end
%end

%group gHideExploreTab
%hook YTPivotBarView
- (void)setRenderer:(YTIPivotBarRenderer *)renderer {
    NSMutableArray <YTIPivotBarSupportedRenderers *> *items = [renderer itemsArray];

    NSUInteger index = [items indexOfObjectPassingTest:^BOOL(YTIPivotBarSupportedRenderers *renderers, NSUInteger idx, BOOL *stop) {
        return [[[renderers pivotBarItemRenderer] pivotIdentifier] isEqualToString:@"FEexplore"];
    }];
    if (index != NSNotFound) [items removeObjectAtIndex:index];

    %orig;
}
%end
%end

%group gHideShortsTab
%hook YTPivotBarView
- (void)setRenderer:(YTIPivotBarRenderer *)renderer {
    NSMutableArray <YTIPivotBarSupportedRenderers *> *items = [renderer itemsArray];

    NSUInteger index = [items indexOfObjectPassingTest:^BOOL(YTIPivotBarSupportedRenderers *renderers, NSUInteger idx, BOOL *stop) {
        return [[[renderers pivotBarItemRenderer] pivotIdentifier] isEqualToString:@"FEshorts"];
    }];
    if (index != NSNotFound) [items removeObjectAtIndex:index];

    %orig;
}
%end
%end

%group gHideUploadTab
%hook YTPivotBarView
- (void)setRenderer:(YTIPivotBarRenderer *)renderer {
    NSMutableArray <YTIPivotBarSupportedRenderers *> *items = [renderer itemsArray];

    NSUInteger index = [items indexOfObjectPassingTest:^BOOL(YTIPivotBarSupportedRenderers *renderers, NSUInteger idx, BOOL *stop) {
        return [[[renderers pivotBarIconOnlyItemRenderer] pivotIdentifier] isEqualToString:@"FEuploads"];
    }];
    if (index != NSNotFound) [items removeObjectAtIndex:index];

    %orig;
}
%end
%end

%group gHideSubscriptionsTab
%hook YTPivotBarView
- (void)setRenderer:(YTIPivotBarRenderer *)renderer {
    NSMutableArray <YTIPivotBarSupportedRenderers *> *items = [renderer itemsArray];

    NSUInteger index = [items indexOfObjectPassingTest:^BOOL(YTIPivotBarSupportedRenderers *renderers, NSUInteger idx, BOOL *stop) {
        return [[[renderers pivotBarItemRenderer] pivotIdentifier] isEqualToString:@"FEsubscriptions"];
    }];
    if (index != NSNotFound) [items removeObjectAtIndex:index];

    %orig;
}
%end
%end

%group gHideLibraryTab
%hook YTPivotBarView
- (void)setRenderer:(YTIPivotBarRenderer *)renderer {
    NSMutableArray <YTIPivotBarSupportedRenderers *> *items = [renderer itemsArray];

    NSUInteger index = [items indexOfObjectPassingTest:^BOOL(YTIPivotBarSupportedRenderers *renderers, NSUInteger idx, BOOL *stop) {
        return [[[renderers pivotBarItemRenderer] pivotIdentifier] isEqualToString:@"FElibrary"];
    }];
    if (index != NSNotFound) [items removeObjectAtIndex:index];

    %orig;
}
%end
%end

// Shorts options
%hook YTReelWatchPlaybackOverlayView
- (void)setNativePivotButton:(id)arg1 {
    if (IsEnabled(@"hideShortsChannelAvatar_enabled")) {}
    else { return %orig; }
}
- (void)setReelLikeButton:(id)arg1 {
    if (IsEnabled(@"hideShortsLikeButton_enabled")) {}
    else { return %orig; }
}
- (void)setReelDislikeButton:(id)arg1 {
    if (IsEnabled(@"hideShortsDislikeButton_enabled")) {}
    else { return %orig; }
}
- (void)setViewCommentButton:(id)arg1 {
    if (IsEnabled(@"hideShortsCommentButton_enabled")) {}
    else { return %orig; }
}
- (void)setRemixButton:(id)arg1 {
    if (IsEnabled(@"hideShortsRemixButton_enabled")) {}
    else { return %orig; }
}
- (void)setShareButton:(id)arg1 {
    if (IsEnabled(@"hideShortsShareButton_enabled")) {}
    else { return %orig; }
}
%end

%hook _ASDisplayView
- (void)didMoveToWindow {
    %orig;
    if ((IsEnabled(@"hideBuySuperThanks_enabled")) && ([self.accessibilityIdentifier isEqualToString:@"id.elements.components.suggested_action"])) { 
        self.hidden = YES; 
    }
}
%end

%hook YTReelWatchRootViewController
- (void)setPausedStateCarouselView {
    if (IsEnabled(@"hideSubcriptions_enabled")) {}
    else { return %orig; }
}
%end

%hook YTColdConfig
- (BOOL)enableResumeToShorts {
    if (IsEnabled(@"disableResumeToShorts")) { return NO; }
    else { return %orig; }
}
%end

// Miscellaneous
// Disable hints - https://github.com/LillieH001/YouTube-Reborn/blob/v4/
%group gDisableHints
%hook YTSettings
- (BOOL)areHintsDisabled {
	return YES;
}
- (void)setHintsDisabled:(BOOL)arg1 {
    %orig(YES);
}
%end
%hook YTUserDefaults
- (BOOL)areHintsDisabled {
	return YES;
}
- (void)setHintsDisabled:(BOOL)arg1 {
    %orig(YES);
}
%end
%end

// Stick Navigation bar
%group gStickNavigationBar
%hook YTHeaderView
- (BOOL)stickyNavHeaderEnabled { return YES; } 
%end
%end

// Hide the Chip Bar (Upper Bar) in Home feed
%group gHideChipBar
%hook YTMySubsFilterHeaderView 
- (void)setChipFilterView:(id)arg1 {}
%end

%hook YTHeaderContentComboView
- (void)enableSubheaderBarWithView:(id)arg1 {}
%end

%hook YTHeaderContentComboView
- (void)setFeedHeaderScrollMode:(int)arg1 { %orig(0); }
%end

// Hide the chip bar under the video player?
// %hook YTChipCloudCell // 
// - (void)didMoveToWindow {
//     %orig;
//     self.hidden = YES;
// }
// %end
%end

%group giPadLayout // https://github.com/LillieH001/YouTube-Reborn
%hook UIDevice
- (long long)userInterfaceIdiom {
    return YES;
} 
%end
%hook UIStatusBarStyleAttributes
- (long long)idiom {
    return NO;
} 
%end
%hook UIKBTree
- (long long)nativeIdiom {
    return NO;
} 
%end
%hook UIKBRenderer
- (long long)assetIdiom {
    return NO;
} 
%end
%end

%group giPhoneLayout // https://github.com/LillieH001/YouTube-Reborn
%hook UIDevice
- (long long)userInterfaceIdiom {
    return NO;
} 
%end
%hook UIStatusBarStyleAttributes
- (long long)idiom {
    return YES;
} 
%end
%hook UIKBTree
- (long long)nativeIdiom {
    return NO;
} 
%end
%hook UIKBRenderer
- (long long)assetIdiom {
    return NO;
} 
%end
%end

// YT startup animation
%hook YTColdConfig
- (BOOL)mainAppCoreClientIosEnableStartupAnimation {
    return IsEnabled(@"ytStartupAnimation_enabled") ? YES : NO;
}
%end

# pragma mark - ctor
%ctor {
    %init;
    if (IsEnabled(@"hideCastButton_enabled")) {
       %init(gHideCastButton);
    }
    if (IsEnabled(@"iPadLayout_enabled")) {
       %init(giPadLayout);
    }
    if (IsEnabled(@"iPhoneLayout_enabled")) {
       %init(giPhoneLayout);
    }
    if (IsEnabled(@"reExplore_enabled")) {
       %init(gReExplore);
    }
    if (IsEnabled(@"bigYTMiniPlayer_enabled") && (UIDevice.currentDevice.userInterfaceIdiom != UIUserInterfaceIdiomPad)) {
       %init(Main);
    }
    if (IsEnabled(@"hideShorts_enabled")) {
        %init(gHideShorts);
    }
    if (IsEnabled(@"hidePreviousAndNextButton_enabled")) {
       %init(gHidePreviousAndNextButton);
    }
    if (IsEnabled(@"replacePreviousAndNextButton_enabled")) {
       %init(gReplacePreviousAndNextButton);
    }
    if (IsEnabled(@"hideOverlayDarkBackground_enabled")) {
       %init(gHideOverlayDarkBackground);
    }
    if (IsEnabled(@"hideVideoPlayerShadowOverlayButtons_enabled")) {
       %init(gHideVideoPlayerShadowOverlayButtons);
    }
    if (IsEnabled(@"disableWifiRelatedSettings_enabled")) {
       %init(gDisableWifiRelatedSettings);
    }
    if (IsEnabled(@"hideHeatwaves_enabled")) {
       %init(gHideHeatwaves);
    }
    if (IsEnabled(@"ytNoModernUI_enabled")) {
       %init(gYTNoModernUI);
    }
    if (IsEnabled(@"disableVideoPlayerZoom_enabled")) {
        %init(gDisableVideoPlayerZoom);
    }
    if (IsEnabled(@"hideYouTubeLogo_enabled")) {
       %init(gHideYouTubeLogo);
    }
    if (IsEnabled(@"disableHints_enabled")) {
        %init(gDisableHints);
    }
    if (IsEnabled(@"redProgressBar_enabled")) {
        %init(gRedProgressBar);
    }
    if (IsEnabled(@"stickNavigationBar_enabled")) {
        %init(gStickNavigationBar);
    }
    if (IsEnabled(@"hideChipBar_enabled")) {
       %init(gHideChipBar);
    }
    if (IsEnabled(@"ytSpeed_enabled")) {
        %init(gYTSpeed);
    }
    if (IsEnabled(@"stockVolumeHUD_enabled")) {
        %init(gStockVolumeHUD);
    }
    if (IsEnabled(@"hideExploreTab_enabled")) {
        %init(gHideExploreTab);
    }
    if (IsEnabled(@"hideShortsTab_enabled")) {
        %init(gHideShortsTab);
    }
    if (IsEnabled(@"hideUploadTab_enabled")) {
        %init(gHideUploadTab);
    }
    if (IsEnabled(@"hideSubscriptionsTab_enabled")) {
        %init(gHideSubscriptionsTab);
    }
    if (IsEnabled(@"hideLibraryTab_enabled")) {
        %init(gHideLibraryTab);
    }

    // Change the default value of some options
    NSArray *allKeys = [[[NSUserDefaults standardUserDefaults] dictionaryRepresentation] allKeys];
    if (![allKeys containsObject:@"RYD-ENABLED"]) { 
       [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"RYD-ENABLED"]; 
    }
    if (![allKeys containsObject:@"YouPiPEnabled"]) { 
       [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"YouPiPEnabled"]; 
	}
}
