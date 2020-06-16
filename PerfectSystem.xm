#import <Cephei/HBPreferences.h>

static HBPreferences *pref;
static BOOL enabled;
static BOOL hideHomeBar;
static BOOL force3DTouch;
static BOOL disableLargeTitles;
static BOOL disableBreadcrumbs;
static BOOL animatedTableCells;
static BOOL disablePIPSizeRestrictions;

static BOOL hasMovedToWindow = NO;

%group hideHomeBarGroup

	%hook MTLumaDodgePillSettings

	- (void)setHeight: (double)arg
	{
		%orig(0);
	}

	%end

%end

%group force3DTouchGroup

	%hook _UITouchDurationObservingGestureRecognizer

	- (void)setMinimumDurationRequired: (double)arg
	{
		%orig(DBL_MAX);
	}

	%end

%end

%group disableLargeTitlesGroup

	%hook UINavigationBar

	- (BOOL)prefersLargeTitles
	{
		return NO;
	}

	%end


%end

%group disableBreadcrumbsGroup

	%hook SBDeviceApplicationSceneStatusBarBreadcrumbProvider

	+ (BOOL)_shouldAddBreadcrumbToActivatingSceneEntity: (id)arg1 sceneHandle: (id)arg2 withTransitionContext: (id)arg3
	{
		return NO;
	}

	%end

%end

%group animatedTableCellsGroup

	/*
		Original tweaks: 
		@rpetrich: https://github.com/rpetrich/Cask
		@efrederickson: https://github.com/efrederickson/Cask
		@ryannair05: https://github.com/ryannair05/Cask-2
	*/

	%hook UIScrollView

	- (BOOL)isDragging
	{
		hasMovedToWindow = !%orig;
		return %orig;
	}

	- (void)_scrollViewWillBeginDragging
	{
		hasMovedToWindow = NO;
		return %orig;
	}

	%end 

	%hook UITableView

	- (UITableViewCell*)_createPreparedCellForGlobalRow: (NSInteger)globalRow withIndexPath: (NSIndexPath *)indexPath willDisplay: (BOOL)willDisplay
	{
		__block UITableViewCell *result = %orig;

		if(hasMovedToWindow) return result;

		dispatch_async(dispatch_get_main_queue(), // SLIDE AND BOUNCE ANIMATION
		^{
			CGRect original = result.frame;
			CGRect newFrame = original;
			CGRect newFrame2 = original;
			newFrame2.origin.x -= 25;
			newFrame.origin.x += original.size.width;
			result.frame = newFrame;
			[UIView animateWithDuration: 0.25 delay: 0.0 
			options: UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionAllowAnimatedContent | UIViewAnimationOptionCurveEaseOut 
			animations: ^{ result.frame = newFrame2; }
			completion: ^(BOOL _) { [UIView animateWithDuration: 0.12 animations: ^{ result.frame = original; }]; }];
		});
		return result;
	}

	%end

%end

%group disablePIPSizeRestrictionsGroup

	%hook SBPIPContentViewLayoutSettings

	+ (CGSize)maximumContentViewSizeForAspectRatio: (CGSize)size
	{
		return size;
	}

	%end

	%hook SBPIPContainerViewController

	- (void)_updateContentViewLayoutConstraintsWithFrame: (CGRect)arg1
	{
		
	}

	- (CGSize)_constrainContentViewSize: (CGSize)size
	{
		return size;
	}

	%end

%end

%ctor
{
	pref = [[HBPreferences alloc] initWithIdentifier: @"com.johnzaro.perfectsystemprefs"];
	[pref registerBool: &enabled default: NO forKey: @"enabled"];
	if(enabled)
	{
		NSString *processName = [NSProcessInfo processInfo].processName;
		bool isSpringboard = [@"SpringBoard" isEqualToString: processName];

		bool shouldLoad = NO;
		NSArray *args = [[NSProcessInfo processInfo] arguments];
		NSUInteger count = args.count;
		if(count != 0)
		{
			NSString *executablePath = args[0];
			if(executablePath)
			{
				NSString *processName = [executablePath lastPathComponent];
				BOOL isApplication = [executablePath rangeOfString: @"/Application/"].location != NSNotFound || [executablePath rangeOfString: @"/Applications/"].location != NSNotFound;
				BOOL isFileProvider = [[processName lowercaseString] rangeOfString: @"fileprovider"].location != NSNotFound;
				BOOL skip = [processName isEqualToString: @"AdSheet"] || [processName isEqualToString: @"CoreAuthUI"]
							|| [processName isEqualToString: @"InCallService"] || [processName isEqualToString: @"MessagesNotificationViewService"]
							|| [executablePath rangeOfString: @".appex/"].location != NSNotFound;
				if(!isFileProvider && isApplication && !skip || isSpringboard)
					shouldLoad = YES;
			}
		}

		if(shouldLoad)
		{
			[pref registerBool: &hideHomeBar default: NO forKey: @"hideHomeBar"];
			[pref registerBool: &force3DTouch default: NO forKey: @"force3DTouch"];
			[pref registerBool: &disableLargeTitles default: NO forKey: @"disableLargeTitles"];
			[pref registerBool: &disableBreadcrumbs default: NO forKey: @"disableBreadcrumbs"];
			[pref registerBool: &animatedTableCells default: NO forKey: @"animatedTableCells"];
			[pref registerBool: &disablePIPSizeRestrictions default: NO forKey: @"disablePIPSizeRestrictions"];

			if(isSpringboard)
			{
				if(disableBreadcrumbs)
					%init(disableBreadcrumbsGroup);

				if(disablePIPSizeRestrictions)
					%init(disablePIPSizeRestrictionsGroup);
			}

			if(!isSpringboard)
			{
				if(animatedTableCells)
					%init(animatedTableCellsGroup);
			}

			if(hideHomeBar)
				%init(hideHomeBarGroup);

			if(force3DTouch)
				%init(force3DTouchGroup);

			if(disableLargeTitles)
				%init(disableLargeTitlesGroup);
		}
	}
}
