//
//  ViewController.m
//  TOPRANDPlayer
//
//  Created by apple on 16/6/1.
//  Copyright © 2016年 TOPRAND. All rights reserved.
//

#import "ViewController.h"
#import "TRDPlayerViewController.h"
#import "Masonry.h"
#import "TRDDownloadManager.h"

@interface ViewController ()

@property (nonatomic, strong) NSArray *localMovies;
@property (nonatomic, strong) NSArray *remoteMovies;


/** 进度UILabel */
@property (strong, nonatomic)  UILabel *progressLabel1;
@property (strong, nonatomic)  UILabel *progressLabel2;
@property (strong, nonatomic)  UILabel *progressLabel3;

/** 进度UIProgressView */
@property (strong, nonatomic)  UIProgressView *progressView1;
@property (strong, nonatomic)  UIProgressView *progressView2;
@property (strong, nonatomic)  UIProgressView *progressView3;

/** 下载按钮 */
@property (strong, nonatomic)  UIButton *downloadButton1;
@property (strong, nonatomic)  UIButton *downloadButton2;
@property (strong, nonatomic)  UIButton *downloadButton3;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor orangeColor];
    [self loadRemoteMovies];
    [self createUI];
    [self refreshDataWithState:DownloadStateSuspended];
}

- (void) createUI{
    // 进度
    self.progressView1 = ({
    
        UIProgressView *progressView = [[UIProgressView alloc]initWithProgressViewStyle:UIProgressViewStyleDefault];
        progressView.progress = 0.0f;
        [self.view addSubview:progressView];
        [progressView mas_makeConstraints:^(MASConstraintMaker *make){
        
            make.left.equalTo(self.view.mas_left).offset(20);
            make.centerY.equalTo(self.view.mas_centerY);
            make.width.mas_equalTo(200);
        }];
        progressView;
    });
    // 百分比
    self.progressLabel1 = ({
        UILabel *progressLabel = [[UILabel alloc] init];
//        progressLabel.backgroundColor = [UIColor blueColor];
        progressLabel.opaque = NO;
        progressLabel.adjustsFontSizeToFitWidth = NO;
        progressLabel.textAlignment = NSTextAlignmentCenter;
        progressLabel.textColor = [UIColor whiteColor];
        progressLabel.text = @"0.0%";
        progressLabel.font = [UIFont systemFontOfSize:12];
        progressLabel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
        [self.view addSubview:progressLabel];
        [progressLabel mas_makeConstraints:^(MASConstraintMaker *make){
            
            make.left.equalTo(self.progressView1.mas_right).offset(10);
            make.centerY.equalTo(self.progressView1.mas_centerY);
            make.width.height.mas_equalTo(50);
        }];
        progressLabel;
    });
    
    self.downloadButton1 = ({
       
        UIButton *downloadButton = [[UIButton alloc]init];
        downloadButton.backgroundColor = [UIColor blueColor];
        downloadButton.selected = NO;
        [downloadButton addTarget:self action:@selector(downloadButtonClick:) forControlEvents:UIControlEventTouchUpInside];
        [self.view addSubview:downloadButton];
        [downloadButton mas_makeConstraints:^(MASConstraintMaker *make){
        
            make.left.equalTo(self.progressLabel1.mas_right).offset(20);
            make.centerY.equalTo(self.progressLabel1.mas_centerY);
            make.width.height.mas_equalTo(50);
        }];
        downloadButton;
    });
    
    // 清空按钮
    UIButton *deleteButton = [[UIButton alloc]init];
    deleteButton.backgroundColor = [UIColor blueColor];
    [deleteButton setTitle:@"清空" forState:UIControlStateNormal];
    [deleteButton addTarget:self action:@selector(deleteButtonClick:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:deleteButton];
    [deleteButton mas_makeConstraints:^(MASConstraintMaker *make){
            
        make.left.equalTo(self.progressLabel1.mas_right).offset(20);
        make.top.equalTo(self.downloadButton1.mas_bottom).offset(10);
        make.width.height.mas_equalTo(50);
    }];
    
    UIButton *playButton = [[UIButton alloc]init];
    playButton.backgroundColor = [UIColor blueColor];
    [playButton setTitle:@"播放" forState:UIControlStateNormal];
    [playButton addTarget:self action:@selector(playButtonClick:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:playButton];
    [playButton mas_makeConstraints:^(MASConstraintMaker *make){
        
        make.left.equalTo(self.progressLabel1.mas_right).offset(20);
        make.top.equalTo(deleteButton.mas_bottom).offset(10);
        make.width.height.mas_equalTo(50);
    }];
}

NSString * const downloadUrl1 = @"http://120.25.226.186:32812/resources/videos/minion_01.mp4";


#pragma mark 刷新数据
- (void)refreshDataWithState:(DownloadState)state
{
    // 获取已下载的进度
    self.progressLabel1.text = [NSString stringWithFormat:@"%.f%%", [[TRDDownloadManager sharedInstance] progress:downloadUrl1] * 100];
    self.progressView1.progress = [[TRDDownloadManager sharedInstance] progress:downloadUrl1];
    [self.downloadButton1 setTitle:[self getTitleWithDownloadState:state] forState:UIControlStateNormal];
}

#pragma mark 按钮状态
- (NSString *)getTitleWithDownloadState:(DownloadState)state
{
     NSString *title = @"";
    // 判断是否已经下载完成
    if ([[TRDDownloadManager sharedInstance] isCompletion:downloadUrl1]) {
        
        return title = @"完成";
    }
    switch (state) {
        case DownloadSateStart:
            title = @"暂停";
            break;
        case DownloadStateSuspended:
        case DownloadStateFailed:
            title = @"开始";
            break;
        case DownloadStateCompleted:
            title = @"完成";
            break;
        default:
            break;
    }
    return title;
}

#pragma mark 开启任务下载资源
- (void)download:(NSString *)url
   progressLabel:(UILabel *)progressLabel
    progressView:(UIProgressView *)progressView
          button:(UIButton *)button{
    
    [[TRDDownloadManager sharedInstance]download:url
                                        progress:^(NSInteger receivedSize, NSInteger expectedSize, CGFloat progress){
                                            dispatch_async(dispatch_get_main_queue(), ^{
                                                
                                                progressLabel.text = [NSString stringWithFormat:@"%.f%%",progress * 100];
                                                progressView.progress = progress;
                                    
                                            });
    }
                                           state:^(DownloadState state){
        
                                               dispatch_async(dispatch_get_main_queue(), ^{
                                               
                                                   [self.downloadButton1 setTitle:[self getTitleWithDownloadState:state] forState:UIControlStateNormal];
                                               });
    }];
}


/**
 *  点击下载按钮
 *
 *  @param button <#button description#>
 */
- (void) downloadButtonClick:(UIButton *)button{
    
    [self download:downloadUrl1
     progressLabel:self.progressLabel1
      progressView:self.progressView1
            button:button];
}

/**
 *  点击清除按钮
 *
 *  @param button <#button description#>
 */
- (void) deleteButtonClick:(UIButton *)button{
    
    [self deleteDownloadFile];
}

- (void) deleteDownloadFile{
    
   [[TRDDownloadManager sharedInstance] deleteFile:downloadUrl1];
   [self.downloadButton1 setTitle:[self getTitleWithDownloadState:DownloadStateSuspended] forState:UIControlStateNormal];
    self.progressView1.progress = [[TRDDownloadManager sharedInstance] progress:downloadUrl1];
}

/**
 *  播放视频
 *
 */

- (void) playButtonClick:(UIButton *)button{
    NSString *path = downloadUrl1;
    if ([[TRDDownloadManager sharedInstance] isCompletion:downloadUrl1]) {
    
        path = [[TRDDownloadManager sharedInstance] videoDownloadUrl:downloadUrl1];
        NSLog(@"本地的视频链接 = %@",path);
    }
    TRDPlayerViewController *playerController = [[TRDPlayerViewController alloc]init];
    playerController.playUrl = path;
    [self.navigationController pushViewController:playerController animated:YES];
}



// 加载远程网络链接
- (void) loadRemoteMovies{
    
    _remoteMovies = @[
                      @"http://www.qeebu.com/newe/Public/Attachment/99/52958fdb45565.mp4",
                      @"http://eric.cast.ro/stream2.flv",
                      @"http://liveipad.wasu.cn/cctv2_ipad/z.m3u8",
                      @"http://www.wowza.com/_h264/BigBuckBunny_175k.mov",
                      @"http://www.wowza.com/_h264/BigBuckBunny_115k.mov",
                      @"rtsp://184.72.239.149/vod/mp4:BigBuckBunny_115k.mov",
                      @"http://santai.tv/vod/test/test_format_1.3gp",
                      @"http://santai.tv/vod/test/test_format_1.mp4",
                      
                      @"rtsp://184.72.239.149/vod/mp4://BigBuckBunny_175k.mov",
                      @"http://santai.tv/vod/test/BigBuckBunny_175k.mov",
                      
                      @"rtmp://aragontvlivefs.fplive.net/aragontvlive-live/stream_normal_abt",
                      @"rtmp://ucaster.eu:1935/live/_definst_/discoverylacajatv",
                      @"rtmp://edge01.fms.dutchview.nl/botr/bunny.flv"
                      ];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
