//
//  ViewController.m
//  AVAudioPlayer
//
//  Created by 陈威杰 on 2017/5/11.
//  Copyright © 2017年 ChenWeiJie. All rights reserved.
//

#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>

/*
 【总结：】
 1. 建议开发者调用 prepareToPlay 方法做准备播放状态，这样做会取得需要的音频硬件并预加载缓冲区。可选调用
 2. 调用 play 正式播放。内部会隐性激活 prepareToPlay 方法。不过在创建时先调用prepareToPlay 准备播放可以降低调用play方法和听到声音输出之间的延迟。
 3. 调用 prepareToPlay 方法后，self.player.playing 属性依旧是为 NO 的，只有调用 play 方法后 self.player.playing 才是 YES，才是真的在播放中。
 4. 通过 stop 和 pause 停止音频播放都是可以恢复继续播放。两者区别在于底层处理上，调用stop方法会撤销调用prepareToPlay时所做的设置。而pause不会 >>> 不是很明白，无法验证
 
 【中断情况：】
 1. 应用退到后台、音频播放播放逐渐消失、回到前台。音频播放恢复复继续播放 >> 实现手机后台也可以播放
 2. 手机锁住，音频播放逐渐消失，解锁手机、音频播放恢复继续播放  >> 实现手机锁住也可以播放
 3. 有facetime、电话呼入，音频播放被打断暂停、呼入结束后、音频没有自动恢复播放。>>> 需自己优化
 
 【请看下一章：处理中断事件】
 */


@interface ViewController ()


@property(nonatomic, strong) AVAudioPlayer *player;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // 注册中断通知
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleInterruption:)
                                                 name:AVAudioSessionInterruptionNotification
                                               object:[AVAudioSession sharedInstance]];
    
    // 注册线路改变通知
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleRouteChange:)
                                                 name:AVAudioSessionRouteChangeNotification
                                               object:[AVAudioSession sharedInstance]];
    
    NSURL *fileUrl = [[NSBundle mainBundle] URLForResource:@"全孝盛 - 迷住(Into You)" withExtension:@"mp3"];
    NSError *error = nil;
    self.player = [[AVAudioPlayer alloc] initWithContentsOfURL:fileUrl error:&error];
    
    if (self.player) {
        // 缓冲、准备播放
        self.player.volume = 0.2;
        self.player.numberOfLoops = -1;
        [self.player prepareToPlay];
    }
    
}

- (void)handleInterruption:(NSNotification *)notification{
    
//    NSLog(@"%@", notification.userInfo);
//    
//    打印：
//    AVAudioPlayer[1226:387229] {  // 中断开始打印输出
//        AVAudioSessionInterruptionTypeKey = 1;
//    }
//    AVAudioPlayer[1226:387229] {  // 中断结束后打印输出
//        AVAudioSessionInterruptionOptionKey = 1;
//        AVAudioSessionInterruptionTypeKey = 0;
//    }
    
//    其中的字段介绍：
//    中断类型（AVAudioSessionInterruptionType）值：
//    AVAudioSessionInterruptionTypeKey = 1;  表示中断开始
//    AVAudioSessionInterruptionTypeKey = 0;  表示中断结束
    
//    如果中断类型为 AVAudioSessionInterruptionTypeEnded，userInfo 字典会包含一个 AVAudioSessionInterruptionOptions 值来表明音频会话是否已经重新激活以及是否可以再次播放
//    AVAudioSessionInterruptionOptionKey;
    
    
    NSDictionary *info = notification.userInfo;
    

    
    AVAudioSessionInterruptionType type = [info[AVAudioSessionInterruptionTypeKey] integerValue];
    
    if (type == AVAudioSessionInterruptionTypeBegan) {
        // 开始处理中断，可以不做处理，系统会自动停止音频播放。我们只需处理呼叫结束后恢复播放就行了。
        // 停止播放
        [self.player stop];
        
    } else {
        // type == AVAudioSessionInterruptionTypeEnded == 0
        // 中断结束的处理
        AVAudioSessionInterruptionOptions option = [info[AVAudioSessionInterruptionOptionKey] integerValue];
        if (option == AVAudioSessionInterruptionOptionShouldResume) {
            // 音频会话已经重新激活以及可以再次播放，就调用play恢复播放
            [self.player play];
        }
    }
    
    
}


/**
 线路切换处理、如耳机插入和拔出
 */
- (void)handleRouteChange:(NSNotification *)notification{
    
    /*
     线路变更发出的通知中包含一个字典 userInfo，该字典带有相应通知发送的原因信息及前一个线路的描述。
     */
    
    NSLog(@"%@", notification.userInfo);
    
    NSDictionary *info = notification.userInfo;
    
    // 判断线路变更发生的原因
    // AVAudioSessionRouteChangeReasonKey 表示变化原因的无符号整数。通过原因可以推断出不同的事件，比如有新设备接入或改变音频会话类型，注意耳机断开事件对应原因为 AVAudioSessionRouteChangeReasonOldDeviceUnavailable
    AVAudioSessionRouteChangeReason reason = [info[AVAudioSessionRouteChangeReasonKey] unsignedIntValue];
    
    // 如果线路变更原因是耳机线拔出的话
    if (reason == AVAudioSessionRouteChangeReasonOldDeviceUnavailable) {
        // 获取前一个线路的描述（AVAudioSessionRouteDescription类型）
        // 线路描述的内容有两种：分别为：输入、输出。他们都是AVAudioSessionPortDescription实例：
            // @property(readonly) NSArray<AVAudioSessionPortDescription *> * inputs;
            // @property(readonly) NSArray<AVAudioSessionPortDescription *> * outputs;
        AVAudioSessionRouteDescription *previousRoute = info[AVAudioSessionRouteChangePreviousRouteKey];
        
        // 从线路描述中找到第一个输出接口并判断其是否为耳机接口，如果是，则停止播放
        AVAudioSessionPortDescription *previousOutput = previousRoute.outputs.firstObject;
        if ([previousOutput.portType isEqualToString:AVAudioSessionPortHeadphones]) {
            [self.player stop];
        }
    }
    
    
}

- (void)dealloc{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (IBAction)star:(id)sender {
    
    if (!self.player.playing) {
        [self.player play];
        // 开始播放
        NSLog(@"%f", self.player.rate);
    }
    
}


/**
 暂停
 */
- (IBAction)pause:(id)sender {
    [self.player pause];
    // 开始播放
    NSLog(@"%f", self.player.rate);
}

/**
 停止
 */
- (IBAction)stop:(id)sender {
    [self.player stop];
    // 开始播放
    NSLog(@"%f", self.player.rate);
}




@end
