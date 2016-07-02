//
//  TRDPlayerView.m
//  TOPRANDPlayer
//
//  Created by apple on 16/6/2.
//  Copyright © 2016年 TOPRAND. All rights reserved.
//

#import "TRDPlayerView.h"
#import <MediaPlayer/MediaPlayer.h>
#import <QuartzCore/QuartzCore.h>
#import "KxMovieDecoder.h"
#import "KxAudioManager.h"
#import "KxMovieGLView.h"
#import "KxLogger.h"
#import "Masonry.h"
#import "UIImageView+DYImageViewCache.h"

#define kScreenW ([UIScreen mainScreen].bounds.size.width)
#define kScreenH ([UIScreen mainScreen].bounds.size.height)
#define kNavbarHeight 0//导航栏高度
#define kTabBarHeight 44//dock条高度

NSString * const KxMovieParameterMinBufferedDuration = @"KxMovieParameterMinBufferedDuration";
NSString * const KxMovieParameterMaxBufferedDuration = @"KxMovieParameterMaxBufferedDuration";
NSString * const KxMovieParameterDisableDeinterlacing = @"KxMovieParameterDisableDeinterlacing";

////////////////////////////////////////////////////////////////////////////////

static NSString * formatTimeInterval(CGFloat seconds, BOOL isLeft)
{
    seconds = MAX(0, seconds);
    
    NSInteger s = seconds;
    NSInteger m = s / 60;
    NSInteger h = m / 60;
    
    s = s % 60;
    m = m % 60;
    
    NSMutableString *format = [(isLeft && seconds >= 0.5 ? @"-" : @"") mutableCopy];
    if (h != 0) [format appendFormat:@"%ld:%0.2ld", (long)h, (long)m];
    else        [format appendFormat:@"%ld", (long)m];
    [format appendFormat:@":%0.2ld", (long)s];
    
    return format;
}

////////////////////////////////////////////////////////////////////////////////

enum {
    
    KxMovieInfoSectionGeneral,
    KxMovieInfoSectionVideo,
    KxMovieInfoSectionAudio,
    KxMovieInfoSectionSubtitles,
    KxMovieInfoSectionMetadata,
    KxMovieInfoSectionCount,
};

enum {
    
    KxMovieInfoGeneralFormat,
    KxMovieInfoGeneralBitrate,
    KxMovieInfoGeneralCount,
};

////////////////////////////////////////////////////////////////////////////////

static NSMutableDictionary * gHistory;

#define LOCAL_MIN_BUFFERED_DURATION   0.2
#define LOCAL_MAX_BUFFERED_DURATION   0.4
#define NETWORK_MIN_BUFFERED_DURATION 2.0
#define NETWORK_MAX_BUFFERED_DURATION 4.0

@interface TRDPlayerView()

{
    
    KxMovieDecoder      *_decoder;
    dispatch_queue_t    _dispatchQueue;
    NSMutableArray      *_videoFrames;
    NSMutableArray      *_audioFrames;
    NSMutableArray      *_subtitles;
    NSData              *_currentAudioFrame;
    NSUInteger          _currentAudioFramePos;
    CGFloat             _moviePosition;
    BOOL                _disableUpdateHUD;
    NSTimeInterval      _tickCorrectionTime;
    NSTimeInterval      _tickCorrectionPosition;
    NSUInteger          _tickCounter;
    BOOL                _fullscreen;
    BOOL                _hiddenHUD;
    BOOL                _fitMode;
    BOOL                _infoMode;
    BOOL                _restoreIdleTimer;
    BOOL                _interrupted;
    
    KxMovieGLView       *_glView;
    UIImageView         *_imageView;
    UIView              *_topHUD;
    UIToolbar           *_topBar;
    UIView              *_bottomBar;
    UISlider            *_progressSlider;
    
    UIButton            *_deleteBtn;
    UIButton            *_playBtn;
    UIButton            *_pauseBtn;
    UIButton            *_zoomBtn;
    UIBarButtonItem     *_rewindBtn;
    UIBarButtonItem     *_fforwardBtn;
    UIBarButtonItem     *_spaceItem;
    UIBarButtonItem     *_fixedSpaceItem;
    
    UIButton            *_doneButton;
    UILabel             *_progressLabel;
    UILabel             *_leftLabel;
    UIButton            *_infoButton;
    UITableView         *_tableView;
    UIActivityIndicatorView *_activityIndicatorView;
    UILabel             *_subtitlesLabel;
    
    UITapGestureRecognizer *_tapGestureRecognizer;
    UITapGestureRecognizer *_doubleTapGestureRecognizer;
    UIPanGestureRecognizer *_panGestureRecognizer;
    UITapGestureRecognizer *_playTapGesture;
    
#ifdef DEBUG
    UILabel             *_messageLabel;
    NSTimeInterval      _debugStartTime;
    NSUInteger          _debugAudioStatus;
    NSDate              *_debugAudioStatusTS;
#endif
    
    CGFloat             _bufferedDuration;
    CGFloat             _minBufferedDuration;
    CGFloat             _maxBufferedDuration;
    BOOL                _buffered;
    
    BOOL                _savedIdleTimer;
    
    NSDictionary        *_parameters;
    NSString            *_imagePath;
    NSString            *_vedioPath;
}

@property (readwrite) BOOL playing;
@property (readwrite) BOOL decoding;
@property (readwrite, strong) KxArtworkFrame *artworkFrame;

@end

@implementation TRDPlayerView

- (instancetype) initWithContentPath:(NSString *)path
                          parameters:(NSDictionary *)dictparameters
                               frame:(CGRect)frame
                 backgroundImagePath:(NSString *)imagePath{
    
    if (self = [super init]) {
        self.backgroundColor = [UIColor blackColor];
        self.frame = frame;
        _imagePath = imagePath;
        _vedioPath = path;
        _parameters = dictparameters;
        [self loadPlayVedioView];
    }
    return self;
}

- (void)loadActivityView{
    
    _activityIndicatorView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle: UIActivityIndicatorViewStyleWhite];
    _activityIndicatorView.center = CGPointMake(self.frame.size.width/2, self.frame.size.height/2);
    _activityIndicatorView.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    [self addSubview:_activityIndicatorView];
    
}
- (void) loadPlayVedioView{
    [self loadActivityView];
    [self viewDidAppear];
    [self contentWithPath:_vedioPath parameters:_parameters];
}

- (void) loadPlayingControl{
    // 底部播放控件
    CGFloat botH = 28;
    _bottomBar = [[UIView alloc] init];//WithFrame:CGRectMake(0, height-botH, width, botH)];
    _bottomBar.backgroundColor = [UIColor clearColor];
    _bottomBar.alpha = 1.0;
    [_glView addSubview:_bottomBar];
    [_bottomBar mas_updateConstraints:^(MASConstraintMaker *make){
        
        make.height.mas_equalTo(28);
        make.right.left.bottom.equalTo(_glView);
    }];
    // 播放按钮
    _playBtn  = ({
      
        UIButton *button = [self returnCommonButtonWithSelected:NO norlmalStateImage:@"playback_pause" selectedStateImage:@"play"];
        [button addTarget:self action:@selector(playButtonClick:) forControlEvents:UIControlEventTouchUpInside];
        button.frame = CGRectMake(0, 0, botH, botH);
        [_bottomBar addSubview:button];
        button;
    });
    
    // 播放的进度
    _progressLabel = ({
    
        UILabel *alreadyTimeLabel  = [[UILabel alloc]init];
        alreadyTimeLabel.text = @"progressLable";
        alreadyTimeLabel.backgroundColor = [UIColor clearColor];
        alreadyTimeLabel.opaque = NO;
        alreadyTimeLabel.adjustsFontSizeToFitWidth = NO;
        alreadyTimeLabel.textAlignment = NSTextAlignmentCenter;
        alreadyTimeLabel.textColor = [UIColor whiteColor];
        alreadyTimeLabel.font = [UIFont systemFontOfSize:12];
        alreadyTimeLabel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
        [_bottomBar addSubview:alreadyTimeLabel];
        [alreadyTimeLabel mas_makeConstraints:^(MASConstraintMaker *make){
            
            make.left.equalTo(_playBtn.mas_right).offset(2);
            make.height.equalTo(_bottomBar.mas_height);
            make.centerY.equalTo(_bottomBar.mas_centerY);
        }];
        alreadyTimeLabel;
    });
    // 缩放
    _zoomBtn = ({
        UIButton *button = [self returnCommonButtonWithSelected:NO norlmalStateImage:@"fullscreen" selectedStateImage:@"nonfullscreen"];
        [button addTarget:self action:@selector(playButtonClick:) forControlEvents:UIControlEventTouchUpInside];
        button.backgroundColor = [UIColor clearColor];
        [button addTarget:self action:@selector(isFullBtnClick:) forControlEvents:UIControlEventTouchUpInside];
        [_bottomBar addSubview:button];
        [button mas_makeConstraints:^(MASConstraintMaker *make){
            
            make.right.equalTo(_bottomBar.mas_right).offset(1);
            make.size.equalTo(_bottomBar.mas_height);
            make.centerY.equalTo(_bottomBar.mas_centerY);
        }];
        button;
    });
    
    // 剩余时间
    _leftLabel = ({
        UILabel *leftTimeLabel = [[UILabel alloc] init];// WithFrame:CGRectMake(width - 50 - _zoomBtn.frame.size.width, 5, 50, botH - 10)];
        leftTimeLabel.backgroundColor = [UIColor clearColor];
        leftTimeLabel.opaque = NO;
        leftTimeLabel.adjustsFontSizeToFitWidth = NO;
        leftTimeLabel.textAlignment = NSTextAlignmentCenter;
        leftTimeLabel.textColor = [UIColor whiteColor];
        leftTimeLabel.text = @"leftLabel";
        leftTimeLabel.font = [UIFont systemFontOfSize:12];
        leftTimeLabel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
        [_bottomBar addSubview:leftTimeLabel];
        [leftTimeLabel mas_makeConstraints:^(MASConstraintMaker *make){
            
            make.right.equalTo(_zoomBtn.mas_left).offset(1);
            make.height.equalTo(_bottomBar.mas_height);
            make.centerY.equalTo(_bottomBar.mas_centerY);
        }];
        leftTimeLabel;
    });
    // 进度条
    _progressSlider = ({
        
        UISlider *sliderView = [[UISlider alloc] init];
        [sliderView setThumbImage:[UIImage imageNamed:@"dot"]  forState:UIControlStateNormal];
        sliderView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        sliderView.continuous = NO;// 设置不连续变化
        sliderView.value = 0;
        [_bottomBar addSubview:sliderView];
        [sliderView mas_makeConstraints:^(MASConstraintMaker *make){
            
            make.right.equalTo(_leftLabel.mas_left).offset(-5);
            make.left.equalTo(_progressLabel.mas_right).offset(5);
            make.height.equalTo(_bottomBar.mas_height);
            make.centerY.equalTo(_bottomBar.mas_centerY);
            make.centerX.equalTo(_bottomBar.mas_centerX);
        }];
        sliderView;
    });
    // 删除播放器
    _deleteBtn = ({
    
        UIButton *deleteButton = [[UIButton alloc]initWithFrame:CGRectMake(2, 2, 20, 20)];
        [deleteButton setBackgroundImage:[UIImage imageNamed:@"ic_close"] forState:0];
        [deleteButton addTarget:self action:@selector(deleteButtonClick:) forControlEvents:UIControlEventTouchUpInside];
        [_glView addSubview:deleteButton];
        deleteButton;
    });
    
    // 添加手势
    [self setUserInteration];
}

- (void) contentWithPath:(NSString *)path parameters:(NSDictionary *)parameters{
    
    id<KxAudioManager> audioManager = [KxAudioManager audioManager];
    [audioManager activateAudioSession];
    NSAssert(path.length > 0, @"empty path");
    _moviePosition = 0;
    _parameters = parameters;
    __weak TRDPlayerView *weakSelf = self;
    KxMovieDecoder *decoder = [[KxMovieDecoder alloc] init];
    decoder.interruptCallback = ^BOOL(){
        
        __strong TRDPlayerView *strongSelf = weakSelf;
        return strongSelf ? [strongSelf interruptDecoder] : YES;
    };
    
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        
        NSError *error = nil;
        [decoder openFile:path error:&error];
        
        __strong TRDPlayerView *strongSelf = weakSelf;
        if (strongSelf) {
            
            dispatch_sync(dispatch_get_main_queue(), ^{
                
                [strongSelf setMovieDecoder:decoder withError:error];
            });
        }
    });
}

- (void) viewDidAppear
{
    [self fullscreenMode:YES];
    
    _savedIdleTimer = [[UIApplication sharedApplication] isIdleTimerDisabled];
    
    [self showHUD: YES];
    
    if (_decoder) {
        
        [self restorePlay];
        
    } else {
        
        [_activityIndicatorView startAnimating];
    }
    // 监听是否触发home键挂起程序.
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationWillResignActive:)
                                                 name:UIApplicationWillResignActiveNotification
                                               object:[UIApplication sharedApplication]];
}

#pragma mark - public

-(void) play
{
    if (self.playing)
        return;
    
    if (!_decoder.validVideo &&
        !_decoder.validAudio) {
        
        return;
    }
    
    if (_interrupted)
        return;
    
    self.playing = YES;
    _interrupted = NO;
    _disableUpdateHUD = NO;
    _tickCorrectionTime = 0;
    _tickCounter = 0;
    
    [self asyncDecodeFrames];
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, 0.1 * NSEC_PER_SEC);
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        [self tick];
    });
    
    if (_decoder.validAudio)
        [self enableAudio:YES];
    
    LoggerStream(1, @"play movie");
}

- (void) setMoviePosition: (CGFloat) position
{
    BOOL playMode = self.playing;
    self.playing = NO;
    _disableUpdateHUD = YES;
    [self enableAudio:NO];
    
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, 0.1 * NSEC_PER_SEC);
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        
        [self updatePosition:position playMode:playMode];
    });
}

#pragma mark - private

- (void) setMovieDecoder: (KxMovieDecoder *) decoder
               withError: (NSError *) error
{
    LoggerStream(2, @"setMovieDecoder");
    
    if (!error && decoder) {
        
        _decoder        = decoder;
        _dispatchQueue  = dispatch_queue_create("KxMovie", DISPATCH_QUEUE_SERIAL);
        _videoFrames    = [NSMutableArray array];
        _audioFrames    = [NSMutableArray array];
        
        if (_decoder.subtitleStreamsCount) {
            _subtitles = [NSMutableArray array];
        }
        
        if (_decoder.isNetwork) {
            
            _minBufferedDuration = NETWORK_MIN_BUFFERED_DURATION;
            _maxBufferedDuration = NETWORK_MAX_BUFFERED_DURATION;
            
        } else {
            
            _minBufferedDuration = LOCAL_MIN_BUFFERED_DURATION;
            _maxBufferedDuration = LOCAL_MAX_BUFFERED_DURATION;
        }
        
        if (!_decoder.validVideo)
            _minBufferedDuration *= 10.0;
        if (_parameters.count) {
            
            id val;
            
            val = [_parameters valueForKey: KxMovieParameterMinBufferedDuration];
            if ([val isKindOfClass:[NSNumber class]])
                _minBufferedDuration = [val floatValue];
            
            val = [_parameters valueForKey: KxMovieParameterMaxBufferedDuration];
            if ([val isKindOfClass:[NSNumber class]])
                _maxBufferedDuration = [val floatValue];
            
            val = [_parameters valueForKey: KxMovieParameterDisableDeinterlacing];
            if ([val isKindOfClass:[NSNumber class]])
                _decoder.disableDeinterlacing = [val boolValue];
            
            if (_maxBufferedDuration < _minBufferedDuration)
                _maxBufferedDuration = _minBufferedDuration * 2;
        }
        
        LoggerStream(2, @"buffered limit: %.1f - %.1f", _minBufferedDuration, _maxBufferedDuration);
        
            // 显示播放界面
        [self setupPresentView];
        
        _progressLabel.hidden   = NO;
        _progressSlider.hidden  = NO;
        _leftLabel.hidden       = NO;
        _infoButton.hidden      = NO;
            
        if (_activityIndicatorView.isAnimating) {
                
            [_activityIndicatorView stopAnimating];
                // 播放
            [self restorePlay];
        }
        
    } else {
        
        [_activityIndicatorView stopAnimating];
        if (!_interrupted)
            [self handleDecoderMovieError: error];
    }
}

- (void) restorePlay
{
    [self play];
}

- (void) setupPresentView
{
    CGRect bounds = CGRectMake(0, 0, self.frame.size.width, self.frame.size.height);
    
    if (_decoder.validVideo) {
        _glView = [[KxMovieGLView alloc] initWithFrame:bounds decoder:_decoder];
    }
    if (!_glView) {
        
        LoggerVideo(0, @"fallback to use RGB video frame and UIKit");
        [_decoder setupVideoFrameFormat:KxVideoFrameFormatRGB];
        _imageView = [[UIImageView alloc] initWithFrame:bounds];
        _imageView.backgroundColor = [UIColor blackColor];
    }
    
    UIView *frameView = [self frameView];
    frameView.contentMode = UIViewContentModeScaleAspectFit;
    frameView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleBottomMargin;
    
    [self insertSubview:frameView atIndex:0];
    
    [self loadPlayingControl];
    
    if (_decoder.validVideo) {
        
    } else {
        
        _imageView.image = [UIImage imageNamed:@"kxmovie.bundle/music_icon.png"];
        _imageView.contentMode = UIViewContentModeCenter;
    }
    
    if (_decoder.duration == MAXFLOAT) {
        
        _leftLabel.text = @"\u221E"; // infinity
        _leftLabel.font = [UIFont systemFontOfSize:14];
        
        CGRect frame;
        
        frame = _leftLabel.frame;
        frame.origin.x += 40;
        frame.size.width -= 40;
        _leftLabel.frame = frame;
        
        frame =_progressSlider.frame;
        frame.size.width += 40;
        _progressSlider.frame = frame;
        
    } else {
        
        [_progressSlider addTarget:self
                            action:@selector(progressDidChange:)
                  forControlEvents:UIControlEventValueChanged];
    }
}
- (void) handleDecoderMovieError: (NSError *) error
{
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Failure", nil)
                                                        message:[error localizedDescription]
                                                       delegate:nil
                                              cancelButtonTitle:NSLocalizedString(@"Close", nil)
                                              otherButtonTitles:nil];
    
    [alertView show];
}

- (UIView *) frameView
{
    return _glView ? _glView : _imageView;
}

- (void) audioCallbackFillData: (float *) outData
                     numFrames: (UInt32) numFrames
                   numChannels: (UInt32) numChannels
{
    if (_buffered) {
        memset(outData, 0, numFrames * numChannels * sizeof(float));
        return;
    }
    
    @autoreleasepool {
        
        while (numFrames > 0) {
            
            if (!_currentAudioFrame) {
                
                @synchronized(_audioFrames) {
                    
                    NSUInteger count = _audioFrames.count;
                    
                    if (count > 0) {
                        
                        KxAudioFrame *frame = _audioFrames[0];
                        
#ifdef DUMP_AUDIO_DATA
                        LoggerAudio(2, @"Audio frame position: %f", frame.position);
#endif
                        if (_decoder.validVideo) {
                            
                            const CGFloat delta = _moviePosition - frame.position;
                            
                            if (delta < -0.1) {
                                
                                memset(outData, 0, numFrames * numChannels * sizeof(float));
#ifdef DEBUG
                                LoggerStream(0, @"desync audio (outrun) wait %.4f %.4f", _moviePosition, frame.position);
                                _debugAudioStatus = 1;
                                _debugAudioStatusTS = [NSDate date];
#endif
                                break; // silence and exit
                            }
                            
                            [_audioFrames removeObjectAtIndex:0];
                            
                            if (delta > 0.1 && count > 1) {
                                
#ifdef DEBUG
                                LoggerStream(0, @"desync audio (lags) skip %.4f %.4f", _moviePosition, frame.position);
                                _debugAudioStatus = 2;
                                _debugAudioStatusTS = [NSDate date];
#endif
                                continue;
                            }
                            
                        } else {
                            
                            [_audioFrames removeObjectAtIndex:0];
                            _moviePosition = frame.position;
                            _bufferedDuration -= frame.duration;
                        }
                        
                        _currentAudioFramePos = 0;
                        _currentAudioFrame = frame.samples;
                    }
                }
            }
            
            if (_currentAudioFrame) {
                
                const void *bytes = (Byte *)_currentAudioFrame.bytes + _currentAudioFramePos;
                const NSUInteger bytesLeft = (_currentAudioFrame.length - _currentAudioFramePos);
                const NSUInteger frameSizeOf = numChannels * sizeof(float);
                const NSUInteger bytesToCopy = MIN(numFrames * frameSizeOf, bytesLeft);
                const NSUInteger framesToCopy = bytesToCopy / frameSizeOf;
                
                memcpy(outData, bytes, bytesToCopy);
                numFrames -= framesToCopy;
                outData += framesToCopy * numChannels;
                
                if (bytesToCopy < bytesLeft)
                    _currentAudioFramePos += bytesToCopy;
                else
                    _currentAudioFrame = nil;
                
            } else {
                
                memset(outData, 0, numFrames * numChannels * sizeof(float));
                //LoggerStream(1, @"silence audio");
#ifdef DEBUG
                _debugAudioStatus = 3;
                _debugAudioStatusTS = [NSDate date];
#endif
                break;
            }
        }
    }
}

- (void) enableAudio: (BOOL) on
{
    id<KxAudioManager> audioManager = [KxAudioManager audioManager];
    
    if (on && _decoder.validAudio) {
        
        audioManager.outputBlock = ^(float *outData, UInt32 numFrames, UInt32 numChannels) {
            
            [self audioCallbackFillData: outData numFrames:numFrames numChannels:numChannels];
        };
        
        [audioManager play];
        
        LoggerAudio(2, @"audio device smr: %d fmt: %d chn: %d",
                    (int)audioManager.samplingRate,
                    (int)audioManager.numBytesPerSample,
                    (int)audioManager.numOutputChannels);
        
    } else {
        
        [audioManager pause];
        audioManager.outputBlock = nil;
    }
}

- (BOOL) addFrames: (NSArray *)frames
{
    if (_decoder.validVideo) {
        
        @synchronized(_videoFrames) {
            
            for (KxMovieFrame *frame in frames)
                if (frame.type == KxMovieFrameTypeVideo) {
                    [_videoFrames addObject:frame];
                    _bufferedDuration += frame.duration;
                }
        }
    }
    
    if (_decoder.validAudio) {
        
        @synchronized(_audioFrames) {
            
            for (KxMovieFrame *frame in frames)
                if (frame.type == KxMovieFrameTypeAudio) {
                    [_audioFrames addObject:frame];
                    if (!_decoder.validVideo)
                        _bufferedDuration += frame.duration;
                }
        }
        
        if (!_decoder.validVideo) {
            
            for (KxMovieFrame *frame in frames)
                if (frame.type == KxMovieFrameTypeArtwork)
                    self.artworkFrame = (KxArtworkFrame *)frame;
        }
    }
    
    if (_decoder.validSubtitles) {
        
        @synchronized(_subtitles) {
            
            for (KxMovieFrame *frame in frames)
                if (frame.type == KxMovieFrameTypeSubtitle) {
                    [_subtitles addObject:frame];
                }
        }
    }
    
    return self.playing && _bufferedDuration < _maxBufferedDuration;
}

- (BOOL) decodeFrames
{
    //NSAssert(dispatch_get_current_queue() == _dispatchQueue, @"bugcheck");
    
    NSArray *frames = nil;
    
    if (_decoder.validVideo ||
        _decoder.validAudio) {
        
        frames = [_decoder decodeFrames:0];
    }
    
    if (frames.count) {
        return [self addFrames: frames];
    }
    return NO;
}

- (void) asyncDecodeFrames
{
    if (self.decoding)
        return;
    
    __weak TRDPlayerView *weakSelf = self;
    __weak KxMovieDecoder *weakDecoder = _decoder;
    
    const CGFloat duration = _decoder.isNetwork ? .0f : 0.1f;
    
    self.decoding = YES;
    dispatch_async(_dispatchQueue, ^{
        
        {
            __strong TRDPlayerView *strongSelf = weakSelf;
            if (!strongSelf.playing)
                return;
        }
        
        BOOL good = YES;
        while (good) {
            
            good = NO;
            
            @autoreleasepool {
                
                __strong KxMovieDecoder *decoder = weakDecoder;
                
                if (decoder && (decoder.validVideo || decoder.validAudio)) {
                    
                    NSArray *frames = [decoder decodeFrames:duration];
                    if (frames.count) {
                        
                        __strong TRDPlayerView *strongSelf = weakSelf;
                        if (strongSelf)
                            good = [strongSelf addFrames:frames];
                    }
                }
            }
        }
        
        {
            __strong TRDPlayerView *strongSelf = weakSelf;
            if (strongSelf) strongSelf.decoding = NO;
        }
    });
}

- (void) tick
{
    if (_buffered && ((_bufferedDuration > _minBufferedDuration) || _decoder.isEOF)) {
        
        _tickCorrectionTime = 0;
        _buffered = NO;
        [_activityIndicatorView stopAnimating];
    }
    
    CGFloat interval = 0;
    if (!_buffered)
        interval = [self presentFrame];
    
    if (self.playing) {
        
        const NSUInteger leftFrames =
        (_decoder.validVideo ? _videoFrames.count : 0) +
        (_decoder.validAudio ? _audioFrames.count : 0);
        
        if (0 == leftFrames) {
            
            if (_decoder.isEOF) {
                
                [self pause];
                [self updateHUD];
                return;
            }
            
            if (_minBufferedDuration > 0 && !_buffered) {
                
                _buffered = YES;
                [_activityIndicatorView startAnimating];
            }
        }
        
        if (!leftFrames ||
            !(_bufferedDuration > _minBufferedDuration)) {
            
            [self asyncDecodeFrames];
        }
        
        const NSTimeInterval correction = [self tickCorrection];
        const NSTimeInterval time = MAX(interval + correction, 0.01);
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, time * NSEC_PER_SEC);
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
            [self tick];
        });
    }
    if ((_tickCounter++ % 3) == 0) {
        [self updateHUD];
    }
}

- (CGFloat) tickCorrection
{
    if (_buffered)
        return 0;
    
    const NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    
    if (!_tickCorrectionTime) {
        
        _tickCorrectionTime = now;
        _tickCorrectionPosition = _moviePosition;
        return 0;
    }
    
    NSTimeInterval dPosition = _moviePosition - _tickCorrectionPosition;
    NSTimeInterval dTime = now - _tickCorrectionTime;
    NSTimeInterval correction = dPosition - dTime;
    
    if (correction > 1.f || correction < -1.f) {
        
        LoggerStream(1, @"tick correction reset %.2f", correction);
        correction = 0;
        _tickCorrectionTime = 0;
    }
    
    return correction;
}

- (CGFloat) presentFrame
{
    CGFloat interval = 0;
    
    if (_decoder.validVideo) {
        
        KxVideoFrame *frame;
        
        @synchronized(_videoFrames) {
            
            if (_videoFrames.count > 0) {
                
                frame = _videoFrames[0];
                [_videoFrames removeObjectAtIndex:0];
                _bufferedDuration -= frame.duration;
            }
        }
        
        if (frame)
            interval = [self presentVideoFrame:frame];
        
    } else if (_decoder.validAudio) {
        
        //interval = _bufferedDuration * 0.5;
        
        if (self.artworkFrame) {
            
            _imageView.image = [self.artworkFrame asImage];
            self.artworkFrame = nil;
        }
    }
    
    if (_decoder.validSubtitles)
        [self presentSubtitles];
    
#ifdef DEBUG
    if (self.playing && _debugStartTime < 0)
        _debugStartTime = [NSDate timeIntervalSinceReferenceDate] - _moviePosition;
#endif
    
    return interval;
}

- (CGFloat) presentVideoFrame: (KxVideoFrame *) frame
{
    if (_glView) {
        
        [_glView render:frame];// 呈现视频画面的View，frame是一帧数据，不断的在调用这个方法，不断地显示一帧帧的画面
        
    } else {
        
        KxVideoFrameRGB *rgbFrame = (KxVideoFrameRGB *)frame;
        _imageView.image = [rgbFrame asImage];
    }
    _moviePosition = frame.position;
    
    return frame.duration;
}

- (void) presentSubtitles
{
    NSArray *actual, *outdated;
    
    if ([self subtitleForPosition:_moviePosition
                           actual:&actual
                         outdated:&outdated]){
        
        if (outdated.count) {
            @synchronized(_subtitles) {
                [_subtitles removeObjectsInArray:outdated];
            }
        }
        
        if (actual.count) {
            
            NSMutableString *ms = [NSMutableString string];
            for (KxSubtitleFrame *subtitle in actual.reverseObjectEnumerator) {
                if (ms.length) [ms appendString:@"\n"];
                [ms appendString:subtitle.text];
            }
            
            if (![_subtitlesLabel.text isEqualToString:ms]) {
                
                CGSize viewSize = self.bounds.size;
#pragma clang diagnostic ignored"-Wdeprecated-declarations"
                CGSize size = [ms sizeWithFont:_subtitlesLabel.font
                             constrainedToSize:CGSizeMake(viewSize.width, viewSize.height * 0.5)
                                 lineBreakMode:NSLineBreakByTruncatingTail];
                _subtitlesLabel.text = ms;
                _subtitlesLabel.frame = CGRectMake(0, viewSize.height - size.height - 10,
                                                   viewSize.width, size.height);
                _subtitlesLabel.hidden = NO;
            }
            
        } else {
            
            _subtitlesLabel.text = nil;
            _subtitlesLabel.hidden = YES;
        }
    }
}

- (BOOL) subtitleForPosition: (CGFloat) position
                      actual: (NSArray **) pActual
                    outdated: (NSArray **) pOutdated
{
    if (!_subtitles.count)
        return NO;
    
    NSMutableArray *actual = nil;
    NSMutableArray *outdated = nil;
    
    for (KxSubtitleFrame *subtitle in _subtitles) {
        
        if (position < subtitle.position) {
            
            break; // assume what subtitles sorted by position
            
        } else if (position >= (subtitle.position + subtitle.duration)) {
            
            if (pOutdated) {
                if (!outdated)
                    outdated = [NSMutableArray array];
                [outdated addObject:subtitle];
            }
            
        } else {
            
            if (pActual) {
                if (!actual)
                    actual = [NSMutableArray array];
                [actual addObject:subtitle];
            }
        }
    }
    
    if (pActual) *pActual = actual;
    if (pOutdated) *pOutdated = outdated;
    
    return actual.count || outdated.count;
}

- (void) showHUD: (BOOL) show
{
    _hiddenHUD = !show;
    _panGestureRecognizer.enabled = _hiddenHUD;
    
    [[UIApplication sharedApplication] setIdleTimerDisabled:_hiddenHUD];
    
    [UIView animateWithDuration:0.5
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionTransitionNone
                     animations:^{
                         
                         CGFloat alpha = _hiddenHUD ? 0 : 1;
                         _bottomBar.alpha = alpha;
                         
                     }
                     completion:nil];
    
}

- (void) fullscreenMode: (BOOL) on
{
    _fullscreen = on;
    UIApplication *app = [UIApplication sharedApplication];
    [app setStatusBarHidden:on withAnimation:UIStatusBarAnimationNone];
}

- (void) updatePosition: (CGFloat) position
               playMode: (BOOL) playMode
{
    [self freeBufferedFrames];
    position = MIN(_decoder.duration - 1, MAX(0, position));
    __weak TRDPlayerView *weakSelf = self;
    dispatch_async(_dispatchQueue, ^{
        
        if (playMode) {
            
            {
                // 拖拽进度条后的进度
                __strong TRDPlayerView *strongSelf = weakSelf;
                if (!strongSelf) return;
                [strongSelf setDecoderPosition: position];
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                
                __strong TRDPlayerView *strongSelf = weakSelf;
                if (strongSelf) {
                    [strongSelf setMoviePositionFromDecoder];
                    [strongSelf play];
                }
            });
            
        } else {
            
            {
                __strong TRDPlayerView *strongSelf = weakSelf;
                if (!strongSelf) return;
                [strongSelf setDecoderPosition: position];
                [strongSelf decodeFrames];
            }
            
            dispatch_async(dispatch_get_main_queue(), ^{
                
                __strong TRDPlayerView *strongSelf = weakSelf;
                if (strongSelf) {
                    
                    [strongSelf enableUpdateHUD];
                    [strongSelf setMoviePositionFromDecoder];
                    [strongSelf presentFrame];
                    [strongSelf updateHUD];
                }
            });
        }
    });
}
- (void) updateHUD
{
    if (_disableUpdateHUD)
        return;
    
    const CGFloat duration = _decoder.duration;
    const CGFloat position = _moviePosition -_decoder.startTime;
    
    if (_progressSlider.state == UIControlStateNormal)
        _progressSlider.value = position / duration;
    _progressLabel.text = formatTimeInterval(position, NO);
    
    if (_decoder.duration != MAXFLOAT)
        _leftLabel.text = formatTimeInterval(duration - position, YES);
}

- (void) freeBufferedFrames
{
    @synchronized(_videoFrames) {
        
        [_videoFrames removeAllObjects];
    }
    
    @synchronized(_audioFrames) {
        
        [_audioFrames removeAllObjects];
        _currentAudioFrame = nil;
    }
    
    if (_subtitles) {
        @synchronized(_subtitles) {
            [_subtitles removeAllObjects];
        }
    }
    _bufferedDuration = 0;
}

- (BOOL) interruptDecoder
{
    return _interrupted;
}
- (void) pause
{
    if (!self.playing)
        return;
    
    self.playing = NO;
    [self enableAudio:NO];
    LoggerStream(1, @"pause movie");
}
// 改变播放的进度
- (void) setDecoderPosition: (CGFloat) position
{
    _decoder.position = position;
}

- (void) setMoviePositionFromDecoder
{
    _moviePosition = _decoder.position;
}

- (void) enableUpdateHUD
{
    _disableUpdateHUD = NO;
}
// 双击播放或者暂停
- (void) doubleTapPauseOrPlay{
    
    if (_playing) {
        
        [self pause];
        _playBtn.selected = YES;
        _playing = NO;
    }
    else{
        [self play];
        _playBtn.selected = NO;
        _playing = YES;
    }
}
// 添加手势
- (void) setUserInteration{
    
    _tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
    _tapGestureRecognizer.numberOfTapsRequired = 1;
    
    _doubleTapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
    _doubleTapGestureRecognizer.numberOfTapsRequired = 2;
    
    [_tapGestureRecognizer requireGestureRecognizerToFail: _doubleTapGestureRecognizer];
    if (_glView) {
        _glView.userInteractionEnabled = YES;
        [_glView addGestureRecognizer:_doubleTapGestureRecognizer];
        [_glView addGestureRecognizer:_tapGestureRecognizer];
    }
}
// 进入全屏
- (void) toFullScreen{

    _bottomBar.alpha = 0;
    [UIView animateWithDuration:0.3f animations:^{
        
        _glView.transform = CGAffineTransformIdentity;
        _glView.transform = CGAffineTransformMakeRotation(M_PI_2);
        _glView.frame = CGRectMake(0,0,kScreenW,kScreenH);
        [[UIApplication sharedApplication].keyWindow addSubview:_glView];
        [_bottomBar mas_remakeConstraints:^(MASConstraintMaker *make){
            make.height.mas_equalTo(28);
            make.top.mas_equalTo(kScreenW - 28);
            make.width.mas_equalTo(kScreenH);
            make.left.mas_equalTo(0);
        }];
    } completion:^(BOOL finished) {
        //取消警告
#pragma clang diagnostic push
#pragma clang diagnostic ignored"-Wdeprecated-declarations"
        [[UIApplication sharedApplication] setStatusBarHidden:YES withAnimation:UIStatusBarAnimationFade];
#pragma clang diagnostic pop
        _fullscreen = YES;
        _bottomBar.alpha = 1;
    }];
    NSLog(@"gggg = %@",_bottomBar);
}
// 恢复原来的位置
- (void)recoverToOldSize{
    
    _bottomBar.alpha = 0;
    [UIView animateWithDuration:0.3f animations:^{
        _glView.transform = CGAffineTransformIdentity;
        _glView.frame = self.bounds;
        [self addSubview:_glView];
        [_bottomBar mas_remakeConstraints:^(MASConstraintMaker *make){
            
            make.height.mas_equalTo(28);
            make.right.left.bottom.equalTo(_glView);
        }];
    }completion:^(BOOL finished) {
        _fullscreen = NO;
        _bottomBar.alpha = 1;
//#pragma clang diagnostic push
#pragma clang diagnostic ignored"-Wdeprecated-declarations"
        [[UIApplication sharedApplication] setStatusBarHidden:NO withAnimation:UIStatusBarAnimationFade];
#pragma clang diagnostic pop
        
    }];
}

#pragma -mark 快速返回 按钮
- (UIButton *) returnCommonButtonWithSelected:(BOOL)selected
                            norlmalStateImage:(NSString *)norlmalStateImage
                           selectedStateImage:(NSString *)selectedStateImage{
    
    UIButton *tempButton = [[UIButton alloc] init];
    tempButton.selected = selected;
    [tempButton setImage:[UIImage imageNamed:norlmalStateImage] forState:UIControlStateNormal];
    [tempButton setImage:[UIImage imageNamed:selectedStateImage] forState:UIControlStateSelected];
    return tempButton;
}

- (void) applicationWillResignActive: (NSNotification *)notification
{
    [self showHUD:YES];
    [self pause];
    
    LoggerStream(1, @"applicationWillResignActive");
}

// 播发和暂停
- (void) playButtonClick:(UIButton *)button{
    
    if (button.selected) {
        button.selected = NO;
        [self play];
    }
    else{
        button.selected = YES;
        [self pause];
    }
}
// 屏幕的缩放
- (void) isFullBtnClick:(UIButton *)button{
    if (button.selected) {
        NSLog(@"放大");
        [self toFullScreen];
        [self play];
    }else{
         NSLog(@"缩小");
        [self recoverToOldSize];
    }
}
// 进度的改变
- (void) progressDidChange: (id) sender
{
    // 当播放完成后再改变进度，防止视频暂停
    [self play];
    NSAssert(_decoder.duration != MAXFLOAT, @"bugcheck");
    UISlider *slider = sender;
    [self setMoviePosition:slider.value * _decoder.duration];
}

- (void)deleteButtonClick:(UIButton *)button{
    
    [self deallocRemovePlayerResource];
    if (self.delegate) {
        
        [self.delegate deletePlayerView];
    }
}
// 手势
- (void) handleTap:(UITapGestureRecognizer *) sender{
    
    if (sender.state == UIGestureRecognizerStateEnded) {
        
        if (sender == _tapGestureRecognizer) {
            // 隐藏或者展示底部控制栏
            [self showHUD: _hiddenHUD];
        } else if (sender == _doubleTapGestureRecognizer) {
            //
            [self doubleTapPauseOrPlay];
        }
        else if (sender == _playTapGesture){
            NSLog(@"播放");
            [self loadPlayVedioView];
        }
    }
}

- (void)deallocRemovePlayerResource{
    
    [self viewWillDisappear];
    
    if (_dispatchQueue) {
        
        _dispatchQueue = NULL;
    }
    [_glView removeFromSuperview];
}

- (void) viewWillDisappear{
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    [_activityIndicatorView stopAnimating];
    
    if (_decoder) {
        
        [self pause];
        if (_moviePosition == 0 || _decoder.isEOF)
            [gHistory removeObjectForKey:_decoder.path];
        else if (!_decoder.isNetwork)
            [gHistory setValue:[NSNumber numberWithFloat:_moviePosition]
                        forKey:_decoder.path];
    }
    
    if (_fullscreen)
        [self fullscreenMode:NO];
    
    [[UIApplication sharedApplication] setIdleTimerDisabled:_savedIdleTimer];
    [_activityIndicatorView stopAnimating];
    _buffered = NO;
    _interrupted = YES;
    LoggerStream(1, @"viewWillDisappear %@", self);
}

- (void) receiveMemoryWarning{
    
    if (self.playing) {
        
        [self pause];
        [self freeBufferedFrames];
        
        if (_maxBufferedDuration > 0) {
            
            _minBufferedDuration = _maxBufferedDuration = 0;
            [self play];
            
            LoggerStream(0, @"didReceiveMemoryWarning, disable buffering and continue playing");
            
        } else {
            
            // force ffmpeg to free allocated memory
            [_decoder closeFile];
            [_decoder openFile:nil error:nil];
            
            [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Failure", nil)
                                        message:NSLocalizedString(@"Out of memory", nil)
                                       delegate:nil
                              cancelButtonTitle:NSLocalizedString(@"Close", nil)
                              otherButtonTitles:nil] show];
        }
        
    } else {
        
        [self freeBufferedFrames];
        [_decoder closeFile];
        [_decoder openFile:nil error:nil];
    }
}

- (void)dealloc{
    
    NSLog(@"已经销毁播放View");
}

@end






































