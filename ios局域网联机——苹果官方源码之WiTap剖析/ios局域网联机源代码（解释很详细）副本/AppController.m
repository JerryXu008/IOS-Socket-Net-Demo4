/*
     File: AppController.m
 Abstract: UIApplication's delegate class, the central controller of the application.
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
/*读我关于简单网络流
 = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
 1.0
 
 SimpleNetworkStreams展示了如何做简单的网络使用NSStream API。 这个样例的目的是非常有限的:它不展示所有你需要实现一个完全成熟的网络产品(下图),相反,它侧重于使用NSStream API将实际的数据量整个网络。
 
 SimpleNetworkStreams应该工作在iPhone OS 2.0和以后。 核心网络概念也适用于Mac OS X。
 
 装箱单
 - - - - - - - - - - - -
 示例包含下列事项:
 
 o读我SimpleNetworkStreams。 txt -这个文件。
 o简化假设。txt -更多的文档。
 SimpleNetworkStreams啊。 xcodeproj——一个Xcode项目示例。
 o资源——该项目笔尖,图片,等等。
 o辅助代码——一个目录的完整的代码不直接相关的主要功能的示例。
 SendController啊。 [hm]——一个视图控制器发送文件。
 ReceiveController啊。 [hm]——一个视图控制器接收文件。
 ReceiveServerController啊。 [hm]——一个视图控制器,实现了一个服务器来接收文件。
 SendServerController啊。 [hm]——一个视图控制器,实现了一个服务器发送文件。
 
 使用示例
 - - - - - - - - - - - - - - - - -
 您可以测试示例与一个设备(使用环回),一个模拟器(使用环回),两个设备,两个模拟器(在不同的机器上),设备和模拟器,设备和Mac命令行,和一个模拟器和Mac命令行。所有设备和模拟器必须在同一wi - fi网络。
 
 测试的GUI是简单的:
 
 1。在一台设备上运行这个程序(或模拟器)。
 
 2。切换到“接收服务器”选项卡并点击开始。
 
 重要:如果服务器失败开始与消息“注册失败”,那么很可能是另一个副本的服务器运行在同一网络。关于这个限制的更多信息,请参阅下面的“简化假设”。
 
 3。切换到“Se*/

#import "AppController.h"
#import "Picker.h"

#define kNumPads 3

// The Bonjour application protocol, which must:
// 1) be no longer than 14 characters
// 2) contain only lower-case letters, digits, and hyphens
// 3) begin and end with lower-case letter or digit
// It should also be descriptive and human-readable
// See the following for more information:
// http://developer.apple.com/networking/bonjour/faq.html
#define kGameIdentifier		@"witap"


@interface AppController ()
- (void) setup;
- (void) presentPicker:(NSString *)name;
@end


#pragma mark -
@implementation AppController

- (void) _showAlert:(NSString *)title
{
	UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:title message:@"Check your networking configuration." delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
	[alertView show];
	[alertView release];
}

- (void) applicationDidFinishLaunching:(UIApplication *)application
{
	CGRect		rect;
	UIView*		view;
	NSUInteger	x, y;
	
	//Create a full-screen window
	_window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
	[_window setBackgroundColor:[UIColor darkGrayColor]];
	
	//Create the tap views and add them to the view controller's view
	rect = [[UIScreen mainScreen] applicationFrame];
	for(y = 0; y < kNumPads; ++y) {
		for(x = 0; x < kNumPads; ++x) {
			view = [[TapView alloc] initWithFrame:CGRectMake(rect.origin.x + x * rect.size.width / (float)kNumPads, rect.origin.y + y * rect.size.height / (float)kNumPads, rect.size.width / (float)kNumPads, rect.size.height / (float)kNumPads)];
			[view setMultipleTouchEnabled:NO];
			[view setBackgroundColor:[UIColor colorWithHue:((y * kNumPads + x) / (float)(kNumPads * kNumPads)) saturation:0.75 brightness:0.75 alpha:1.0]];
			[view setTag:(y * kNumPads + x + 1)];
			[_window addSubview:view];
			[view release];
		}
	}
	
	//Show the window
	[_window makeKeyAndVisible];
	
	//Create and advertise a new game and discover other availble games
	[self setup];
}

- (void) dealloc
{
	[_inStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
	[_inStream release];
    
	[_outStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
	[_outStream release];
    
	[_server release];
	
	[_picker release];
	[_window release];
	
	[super dealloc];
}

- (void) setup {
	[_server release];
	_server = nil;
	
	[_inStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
	[_inStream release];
	_inStream = nil;
	_inReady = NO;
    
	[_outStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
	[_outStream release];
	_outStream = nil;
	_outReady = NO;
	
	_server = [TCPServer new];
	[_server setDelegate:self];
	NSError *error = nil;
	if(_server == nil || ![_server start:&error]) { //绑定端口，开始监听
		if (error == nil) {
			NSLog(@"Failed creating server: Server instance is nil");
		} else {
            NSLog(@"Failed creating server: %@", error);
		}
		[self _showAlert:@"Failed creating server"];
		return;
	}
	
	//Start advertising to clients, passing nil for the name to tell Bonjour to pick use default name
    //发布服务
	if(![_server enableBonjourWithDomain:@"local" applicationProtocol:[TCPServer bonjourTypeFromIdentifier:kGameIdentifier] name:nil]) {
		[self _showAlert:@"Failed advertising server"];
		return;
	}
    //读取其他的服务，显示列表
	[self presentPicker:nil];
}

// Make sure to let the user know what name is being used for Bonjour advertisement.
// This way, other players can browse for and connect to this game.
// Note that this may be called while the alert is already being displayed, as
// Bonjour may detect a name conflict and rename dynamically.

//参数name：参数name的，它的作用是传给AppController的变量_picker，让_picker设置自己的一个Label的显示内容的。另外还有就是设置browserviewcontrolle的ownName属性
//就是确定自身服务的名字，同时在ownName的set方法里面会同时设置自己的ownEntry（服务）
- (void) presentPicker:(NSString *)name {
	if (!_picker) {
        //初始化picker，这个初始化的方法里做的东西还是很多的。1初始化一个BrowserViewController，并且立即进行搜索，搜索完之后更新表格显示更新列表。2布局自身，包括吧BrowserViewController view加进去，结合成一个view
		_picker = [[Picker alloc] initWithFrame:[[UIScreen mainScreen] applicationFrame] type:[TCPServer bonjourTypeFromIdentifier:kGameIdentifier]];
		_picker.delegate = self;
	}
	//这个方法里的逻辑也是不少，首先是给标签赋予本设备的名字，还有就是如果name是有意义的，而且服务已经搜索出来了，在服务发布成功之后的回调方法（- (void) serverDidEnableBonjour:(TCPServer *)server withName:(NSString *)string
    //）里面会调用他，然后会在browserviewcontroller的一个方法（setOwnName）里面根据name找出对应的服务，赋值给ownEntry
	_picker.gameName = name;
    
	if (!_picker.superview) {
		[_window addSubview:_picker];
	}
}
//把服务列表移除，销毁，显示
- (void) destroyPicker {
	[_picker removeFromSuperview];
	[_picker release];
	_picker = nil;
}

// If we display an error or an alert that the remote disconnected, handle dismissal and return to setup
- (void) alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
	[self setup];
}
// 这个是用来发送消息对无端设备的，其实就是向输出流写入数据。
- (void) send:(const uint8_t)message
{
	if (_outStream && [_outStream hasSpaceAvailable])
		if([_outStream write:(const uint8_t *)&message maxLength:sizeof(const uint8_t)] == -1)
			[self _showAlert:@"Failed sending data to peer"];
}
//游戏中色块的激活和去激活方法，它们的实现内容都是调用send方法，不同的是向send方法发送的数据不一样。
- (void) activateView:(TapView *)view
{
	[self send:[view tag] | 0x80];
}
//游戏中色块的激活和去激活方法，它们的实现内容都是调用send方法，不同的是向send方法发送的数据不一样。
- (void) deactivateView:(TapView *)view
{
	[self send:[view tag] & 0x7f];
}
//打开输入输出流
- (void) openStreams
{
	_inStream.delegate = self;
	[_inStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
	[_inStream open];
	_outStream.delegate = self;
	[_outStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
	[_outStream open];
}
//解析成功之后调用的回调方法（这个时候就已经连接了，这个方法只是针对的发送方）  参数二：传过来的是解析出来的服务，不是自身的服务，得到的输入流和输出流也是对方的
//按照我的理解 _inStream第一次有值是在解析之后的回调方法里有的（(void) browserViewController:(BrowserViewController *)bvc didResolveInstance:(NSNetService *)netService）
//而这个方法是在比如说有A和B的设备，A检测到了B，B检测到了A，此时只是搜索到了对方的服务，但是彼此并没有解析对方，解析方法是在点击之后执行的，比如在A设备中点击搜索到的一行B，此时会
//进行解析活动，解析成功后会调用（(void) browserViewController:(BrowserViewController *)bvc didResolveInstance:(NSNetService *)netService）
//这时候会得到对方服务的输入输出流，也就是这时候instream和outstream有值了。但此时针对的只是设备A，此时设备B的流还是null，要调用
- (void) browserViewController:(BrowserViewController *)bvc didResolveInstance:(NSNetService *)netService
{
	if (!netService) {
		[self setup];
		return;
	}
    
	// note the following method returns _inStream and _outStream with a retain count that the caller must eventually release
    //	通过引用获取输入和输出流的接收机和返回一个布尔值表明他们是否被成功检索到（苹果官方文档）。
    
    if (![netService getInputStream:&_inStream outputStream:&_outStream]) {
		[self _showAlert:@"Failed connecting to server"];
		return;
	}
    //打开这个service的输入流和输出流
	[self openStreams];
}

@end


#pragma mark -
@implementation AppController (NSStreamDelegate)
// 这个方法比较重要，这个是流的协议方法。根据不同的流事件做不同的处理：（这个方法不管是接收者还是请求者都会走）
- (void) stream:(NSStream *)stream handleEvent:(NSStreamEvent)eventCode
{
	UIAlertView *alertView;
	switch(eventCode) {
            //当流事件是流打开完成的时候，销毁_picker，释放_service，根据触发事件的流设置对就的准备好状态为真，当输入输出两个流都准备好的时候，显示一个警告窗口告诉我们游戏开始。
            
		case NSStreamEventOpenCompleted:
		{
			[self destroyPicker];
			//经过调试，在是请求者的情况下，_server release之前是有值的，server是在这里释放的 。 如果 是在接收者的情况下，之前server已经释放了，并赋予了nil，是在
            //- (void)didAcceptConnectionForServer:(TCPServer *)server inputStream:(NSInputStream *)istr outputStream:(NSOutputStream *)ost 这个方法，中，参数一一直是TCPserver本身，在这里正好可以释放掉，为了防止释放后在释放，所以会赋予nil
			[_server release];
			_server = nil;
            
			if (stream == _inStream)
				_inReady = YES;
			else
				_outReady = YES;
			
			if (_inReady && _outReady) {
				alertView = [[UIAlertView alloc] initWithTitle:@"Game started!" message:nil delegate:nil cancelButtonTitle:nil otherButtonTitles:@"Continue", nil];
				[alertView show];
				[alertView release];
			}
			break;
		}
            // 当流事件是有可用数据的时候，判断这个触发事件的流是不是输入流，如果是就处理，不是就不处理。当是输入流触发事件的时候，从流中读出信息，如果读取出错的话显示一个警告，如果成功的话，根据得到的数据，相应的激活或去激活相应的色块。（具体这个地方的位运算，只要把send方法发送的数据转成2进制就明白这个地方位运算的意义了）
            
		case NSStreamEventHasBytesAvailable:
		{
			if (stream == _inStream) {
				uint8_t b;   // unsigned char 无符号字符类型  1个字节
                //typedef signed char int8_t;  1个字节
                // typedef unsigned char uint8_t;
                // typedef int int16_t;   2个字节
                // typedef unsigned int uint16_t;
                // typedef long int32_t;   4个字节
                // typedef unsigned long uint32_t;
                //typedef long long int64_t;   8个字节
                //typedef unsigned long long uint64_t;
                //typedef int16_t intptr_t;
                //typedef uint16_t uintptr_t;
				int len = 0;
				len = [_inStream read:&b maxLength:sizeof(uint8_t)];
				if(len <= 0) {
					if ([stream streamStatus] != NSStreamStatusAtEnd)
						[self _showAlert:@"Failed reading data from peer"];
				} else {
					//We received a remote tap update, forward it to the appropriate view
					if(b & 0x80) //这个0x80和0x7f的意思我还是不理解
						[(TapView *)[_window viewWithTag:b & 0x7f] touchDown:YES];
					else
						[(TapView *)[_window viewWithTag:b] touchUp:YES];
				}
			}
			break;
		}
            //当流事件是出现错误的时候，显示一个警告。（前面已经说过了如果这个警告上的按钮被点击的话会调用setup方法重新开始整个过程）
            
		case NSStreamEventErrorOccurred:
		{
			//NSLog(@"%s", _cmd);
			[self _showAlert:@"Error encountered on stream!"];
			break;
		}
			//   当流事件是流已经结束的时候（比如远端设备连接断开的时候），把所有色块恢复原始状态，显示一个警告，说明对方断开连接。
            
		case NSStreamEventEndEncountered:
		{
			NSArray		*array = [_window subviews];
			TapView		*view;
			UIAlertView	*alertView;
			
			//NSLog(@"%s", _cmd);
			
			//Notify all tap views
			for(view in array)
				[view touchUp:YES];
			
			alertView = [[UIAlertView alloc] initWithTitle:@"Peer Disconnected!" message:nil delegate:self cancelButtonTitle:nil otherButtonTitles:@"Continue", nil];
			[alertView show];
			[alertView release];
            
			break;
		}
	}
}

@end


#pragma mark -
@implementation AppController (TCPServerDelegate)
//在NSNetService发布成功的回调里调用的，通过调试，我发觉他和BrowserViewController的- (void)netServiceBrowser:(NSNetServiceBrowser *)netServiceBrowser didFindService:(NSNetService *)service moreComing:(BOOL)moreComing {
//这两个的调用顺序是不一定的，第一个是发布成功之后的回调函数，第二个是搜索到可用服务（包括自己）的时候的回调函数，但是按照常理来讲应该是第一个先调用，我也是这么理解的，这样更容易理解
- (void) serverDidEnableBonjour:(TCPServer *)server withName:(NSString *)string
{
	NSLog(@"%s", _cmd);
	[self presentPicker:string];
}
//（这个地方我是没有弄明白的，不知道究竟TCPServerAcceptCallBack是在什么情况下调用的，是在解析完之后呢还是发送数据的时候呢，一直困扰这我，现在我明白了，这个方法的调用顺序是不一定的
//最早的话是在发送方打开流之后，如果打开之后立即发送数据，那么这个方法也有可能在发送数据的时候调用，但按照本案例来说，发送数据是手动发送，所以是第一种情况，打开流）
//socekt收到连接成功后调用回调函数TCPServerAcceptCallBack里面，会调用这个方法，参数一是自身的server（是接收者的，不是发送者的）参数二：发送者的输入流 参数三：发送者的输出流
//这个是在接受了服务的连接请求之后调用的（这个方法只会在被动连接的一方设备上调用）。如果输入或输出流其中有一个有效或者这个方法中的server参数不是这个被连接的设备上的服务本身的话，直接返回。
//如果不是上述情况的话，就释放并停止这个服务，把它赋为nil，把输入输出流赋值为参数istr和ostr，打开输入输出流。

//这个是在TCPserver接收到连接请求（），，在socket的回调方法TCPServerAcceptCallBack
//绑定好新的socket的输入流和输出流之后，调用这个方法。
/**下面的推断较早，现在可以不看了
 //按照我的理解 _inStream第一次有值（这只是针对的发送方，接收方是不会调用这个方法的）是在解析之后的回调方法里有的（(void) browserViewController:(BrowserViewController *)bvc didResolveInstance:(NSNetService *)netService）
 //而这个方法是在比如说有A和B的设备，A检测到了B，B检测到了A，此时只是搜索到了对方的服务，但是彼此并没有解析对方，解析方法是在点击之后执行的，比如在A设备中点击搜索到的一行B，此时会
 //进行解析活动，解析成功后会调用（(void) browserViewController:(BrowserViewController *)bvc didResolveInstance:(NSNetService *)netService）
 //这时候会得到对方服务的输入输出流，也就是这时候instream和outstream有值了。但此时针对的只是设备A，此时设备B的流还是null
 //要使B的流也存在，下面的这个方法是关键的，这个方法是在socekt收到连接成功后调用回调函数TCPServerAcceptCallBack里面，会调用这个方法，就是说A设备发出连接请求（就是需要解析B的地址），
 //下面这个方法是针对设备B的，（与接收方有关，A是请求方，他之后调用请求连接的逻辑，B是针对接受方面的逻辑
 //） 很显然，正常情况下 _inStream和_outStream是null，并且server(在TCPServerAcceptCallBack方法的逻辑中)和_server是一个，都是自己的server，所以条件时不成立的，所以执行后面的逻辑
 //现在好了，设备B有了A的输入流和输出流 ，而A有了B的输入流和输出流（在- (void) browserViewController:(BrowserViewController *)bvc didResolveInstance:(NSNetService *)netService
 //方法中得到的），就可以进行传递数据啦，不知道理解对不对哈，没有两个机器进行调试，纯粹猜测*/
- (void)didAcceptConnectionForServer:(TCPServer *)server inputStream:(NSInputStream *)istr outputStream:(NSOutputStream *)ostr
{
	if (_inStream || _outStream || server != _server)
		return;
	
	[_server release];
	_server = nil;
	
	_inStream = istr;
	[_inStream retain];
	_outStream = ostr;
	[_outStream retain];
	
	[self openStreams];
}

@end
