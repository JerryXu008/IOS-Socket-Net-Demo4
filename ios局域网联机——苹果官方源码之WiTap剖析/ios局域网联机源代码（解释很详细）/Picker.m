/*
     File: Picker.m
 Abstract: A view that displays both the currently advertised game name and a list of other games
 available on the local network - discovered & displayed by BrowserViewController.
 Version: 1.8
 
 Disclaimer: IMPORTANT:  This Apple software is supplied to you by Apple
 Inc. ("Apple") in consideration of your agreement to the following
 terms, and your use, installation, modification or redistribution of
 this Apple software constitutes acceptance of these terms.  If you do
 not agree with these terms, please do not use, install, modify or
 redistribute this Apple software.
 
 In consideration of your agreement to abide by the following terms, and
 subject to these terms, Apple grants you a personal, non-exclusive
 license, under Apple's copyrights in this original Apple software (the
 "Apple Software"), to use, reproduce, modify and redistribute the Apple
 Software, with or without modifications, in source and/or binary forms;
 provided that if you redistribute the Apple Software in its entirety and
 without modifications, you must retain this notice and the following
 text and disclaimers in all such redistributions of the Apple Software.
 Neither the name, trademarks, service marks or logos of Apple Inc. may
 be used to endorse or promote products derived from the Apple Software
 without specific prior written permission from Apple.  Except as
 expressly stated in this notice, no other rights or licenses, express or
 implied, are granted by Apple herein, including but not limited to any
 patent rights that may be infringed by your derivative works or by other
 works in which the Apple Software may be incorporated.
 
 The Apple Software is provided by Apple on an "AS IS" basis.  APPLE
 MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
 THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS
 FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND
 OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.
 
 IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL
 OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION,
 MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED
 AND WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE),
 STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE
 POSSIBILITY OF SUCH DAMAGE.
 
 Copyright (C) 2010 Apple Inc. All Rights Reserved.
 
 */

#import "Picker.h"

#define kOffset 5.0

@interface Picker ()
@property (nonatomic, retain, readwrite) BrowserViewController *bvc;
@property (nonatomic, retain, readwrite) UILabel *gameNameLabel;
@end

@implementation Picker

@synthesize bvc = _bvc;
@synthesize gameNameLabel = _gameNameLabel;


//Picker类的初始化方法
- (id)initWithFrame:(CGRect)frame type:(NSString*)type {
	if ((self = [super initWithFrame:frame])) {  //根据参数frame的大小初始化这个picker类（它是继承自UIView的）。
        
		// add autorelease to the NSNetServiceBrowser to release the browser once the connection has been
		// established. An active browser can cause a delay in sending data.
		// <rdar://problem/7000938>
        //对bvc属性（BrowserViewController类）进行初始化，并在特定域中搜索特定服务
		self.bvc = [[[BrowserViewController alloc] initWithTitle:nil showDisclosureIndicators:NO showCancelButton:NO]autorelease];
		[self.bvc searchForServicesOfType:type inDomain:@"local"];
	    //设置自己为不透明，并设置自己的背景颜色
		self.opaque = YES;
		self.backgroundColor = [UIColor blackColor];
		//给自己加一个背景图片。
        UIImageView* img = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"bg.png"]];
		[self addSubview:img];
		[img release];
		
		CGFloat runningY = kOffset;
		CGFloat width = self.bounds.size.width - 2 * kOffset;
		//给自己加3个label，其中包括一个就是gameNameLabel属性，gameNameLabel属性用来显示游戏的名字
        //（目前只是设置为@""了，但是在上一篇文章中我们已经了解了，当它搜索到自己发布的服务的时候，会把它设置自己发布的服务的名字），其它两个label是显示的一些提示性信息。
        
		UILabel* label = [[UILabel alloc] initWithFrame:CGRectZero];
		[label setTextAlignment:UITextAlignmentCenter];
		[label setFont:[UIFont boldSystemFontOfSize:15.0]];
		[label setTextColor:[UIColor whiteColor]];
		[label setShadowColor:[UIColor colorWithWhite:0.0 alpha:0.75]];
		[label setShadowOffset:CGSizeMake(1,1)];
		[label setBackgroundColor:[UIColor clearColor]];
		label.text = @"Waiting for another player to join game:";
		label.numberOfLines = 1;
		[label sizeToFit];
		label.frame = CGRectMake(kOffset, runningY, width, label.frame.size.height);
		[self addSubview:label];
		
		runningY += label.bounds.size.height;
		[label release];
		
		self.gameNameLabel = [[UILabel alloc] initWithFrame:CGRectZero];
		[self.gameNameLabel setTextAlignment:UITextAlignmentCenter];
		[self.gameNameLabel setFont:[UIFont boldSystemFontOfSize:24.0]];
		[self.gameNameLabel setLineBreakMode:UILineBreakModeTailTruncation];
		[self.gameNameLabel setTextColor:[UIColor whiteColor]];
		[self.gameNameLabel setShadowColor:[UIColor colorWithWhite:0.0 alpha:0.75]];
		[self.gameNameLabel setShadowOffset:CGSizeMake(1,1)];
		[self.gameNameLabel setBackgroundColor:[UIColor clearColor]];
		[self.gameNameLabel setText:@"Default Name"];
		[self.gameNameLabel sizeToFit];
		[self.gameNameLabel setFrame:CGRectMake(kOffset, runningY, width, self.gameNameLabel.frame.size.height)];
		[self.gameNameLabel setText:@""];
		[self addSubview:self.gameNameLabel];
		
		runningY += self.gameNameLabel.bounds.size.height + kOffset * 2;
		
		label = [[UILabel alloc] initWithFrame:CGRectZero];
		[label setTextAlignment:UITextAlignmentCenter];
		[label setFont:[UIFont boldSystemFontOfSize:15.0]];
		[label setTextColor:[UIColor whiteColor]];
		[label setShadowColor:[UIColor colorWithWhite:0.0 alpha:0.75]];
		[label setShadowOffset:CGSizeMake(1,1)];
		[label setBackgroundColor:[UIColor clearColor]];
		label.text = @"Or, join a different game:";
		label.numberOfLines = 1;
		[label sizeToFit];
		label.frame = CGRectMake(kOffset, runningY, width, label.frame.size.height);
		[self addSubview:label];
		
		runningY += label.bounds.size.height + 2;
		//设置Picker类的bvc属性的view（即BrowserViewController这个tableViewController的tableView）的显示范围，并把这个bvc的view作为子视图加入到picker里
		[self.bvc.view setFrame:CGRectMake(0, runningY, self.bounds.size.width, self.bounds.size.height - runningY)];
		[self addSubview:self.bvc.view];
		
	}
    
	return self;
}
//清理操作
- (void)dealloc {
	// Cleanup any running resolve and free memory
	[self.bvc release];
	[self.gameNameLabel release];
	
	[super dealloc];
}
//delegate 的get方法      delegate的get方法返回的是这个Picker类的bvc属性的delegate
- (id<BrowserViewControllerDelegate>)delegate {
	return self.bvc.delegate;
}
//delegate的set方法  set方法也是设置的这个Picker类的bvc属性的delegate
- (void)setDelegate:(id<BrowserViewControllerDelegate>)delegate {
	[self.bvc setDelegate:delegate];
}
//get方法是返回这个Picker类的gameLabel属性的text
- (NSString *)gameName {
	return self.gameNameLabel.text;
}
//set方法不光设置了Picker类的gameLabel的text，还对这个Picker类的bvc调用了ownName 的 set方法
- (void)setGameName:(NSString *)string {
	[self.gameNameLabel setText:string];
	[self.bvc setOwnName:string];
}

@end
