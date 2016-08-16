/*
     File: TCPServer.m
 Abstract: A TCP server that listens on an arbitrary port.
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

#include <sys/socket.h>
#include <netinet/in.h>
#include <unistd.h>
#include <CFNetwork/CFSocketStream.h>

#import "TCPServer.h"

NSString * const TCPServerErrorDomain = @"TCPServerErrorDomain";

@interface TCPServer ()
@property(nonatomic,retain) NSNetService* netService;//用来发布服务的NSNetService
@property(assign) uint16_t port;// //存储我们发布服务时绑定的Socket的端口号
@end

@implementation TCPServer

@synthesize delegate=_delegate, netService=_netService, port=_port;

- (id)init {
    return self;
}
//这会在我们这个类销毁时调用，这个方法里是先调用stop方法停掉网络连接服务，然后调用父类的dealloc方法
- (void)dealloc {
    [self stop];
    [super dealloc];
}
//　在这个方法里，我们先判断self的委托是否为空（我们在AppController.m的setup方法里的注释4中，把委托设为了AppController），并判断这个委托响不响应didAcceptConnectionForServer:inputStream:outputStream:方法，如果响应，就对self的委托调用这个方法来处理一些事情。
//参数一：发送方的地址数据 参数二：连接发送方和接收方的socket的输入流 参数三：连接发送方和接收方的socket的输出流
- (void)handleNewConnectionFromAddress:(NSData *)addr inputStream:(NSInputStream *)istr outputStream:(NSOutputStream *)ostr {
    // if the delegate implements the delegate method, call it
    if (self.delegate && [self.delegate respondsToSelector:@selector(didAcceptConnectionForServer:inputStream:outputStream:)]) {
        [self.delegate didAcceptConnectionForServer:self inputStream:istr outputStream:ostr];
    }
}

// This function is called by CFSocket when a new connection comes in.
// We gather some data here, and convert the function call to a method
// invocation on TCPServer.
//这个方法只是接收者再用，发送者是不会调用这个方法的
//这是一个回调方法，在我们的监听网络连接的socket，接收到连接事件后，这个回调方法就被调用。（通过调试，我发现这个方法一般是在打开流之后调用，就是 stream open，具体调试可以参照 简单局域网NSoutstream应用那个案例）
//具体分析什么时候调用：这个方法只是针对接收者，发送方想请求连接本类，那究竟是在什么时候调用的这个呢，你知道在start方法中socekt已经加入到运行循环了，会不断监听。当发送方点击表格的行之后，会对本服务进行解析（发送方
//通过browser方法搜索到的，但在解析之前不了机是否有效，也不知道服务的具体信息，解析的方法是[self.currentResolve resolveWithTimeout:0.0]; 解析过程或者解析完之后是不会调用这个方法的，因为只是分析，并没有实质性的连接)。之后发送者会调用
//	[self.delegate browserViewController:self didResolveInstance:service];这个方法在AppController.cs中，他（发送方）做的是调用 if (![netService getInputStream:&_inStream outputStream:&_outStream])
//这句代码的意思是取得接收方服务的输入流和输出流，以便用于读写。这个时候还是没有调用本方法，然后是在	[self openStreams];打开了流，也就是连接上了接收方的服务，这个时候才会去调用本方法，
//不过在这之前会先调用流处理方法（- (void) stream:(NSStream *)stream handleEvent:(NSStreamEvent)eventCode）,首先是走的NSStreamEventOpenCompleted即成功打开之后的逻辑，如果还有 NSStreamEventHasSpaceAvailable即需要写入流的时候
//有可能也会先调用这个，即打开流之后马上发送数据，而本回调方法也有可能对方发过来数据的时候在调用（顺序是不唯一的，但是保证只调用了一次，我认为是这样）
//参数类型： 参数一：触发了这个回调的socket本身  参数二：触发这个回调的事件类型  参数三：请求连接的远端设备的地址  参数四：它根据回调事件的不同，它代表的东西也不同，如果这个是连接失败回调事件，那它就代表一个错误代码的指针，
//如果是连接成功的回调事件，它就是一个Socket指针，如果是数据回调事件，这就是包含这些数据的指针，其它情况下它是NULL的 参数五：创建socket的时候用的那个CFSocketContext结构的info成员
static void TCPServerAcceptCallBack(CFSocketRef socket, CFSocketCallBackType type, CFDataRef address, const void *data, void *info) {
    //把这个函数的参数info转成了一个TCPServer类型,这里的info参数就是触发这个回调的socket在被创建时，传入到创建函数里的CFSocketContext结构的info成员
    TCPServer *server = (TCPServer *)info;
    if (kCFSocketAcceptCallBack == type) {  //判断一下我们这次回调的事件类型，如果事件是成功连接我们就进行一系列操作，否则我们什么也不做（）
        // for an AcceptCallBack, the data parameter is a pointer to a CFSocketNativeHandle
        //这个函数的参数data转成了一个CFSocketNativeHandle类型,这个CFSocketNativeHandle类型其实就是我们的特定平台的socket,你就当成正常的socket理解就行了
        //我们知道，在正常的socket流程中，作为服务器的一方会有一个socket一直处于监听连接的状态，一旦有新的连接请求到来，系统会自己创建一个新的socket与这个请求的客户端进行连接，
        //此后客户端和服务器端就通过这个新的连接进行通讯，而服务器负责监听网络连接的socket则继续监听连接。现在这个函数里的这个data应该就是在响应连接请求的时候系统自己创建的新的socket吧
        CFSocketNativeHandle nativeSocketHandle = *(CFSocketNativeHandle *)data;
        //申请了一个255大小的数组用来接收这个新的data转成的socket的地址
        uint8_t name[SOCK_MAXADDRLEN];
        //申请了一个socklen_t变量来接收这个地址结构的大小
        socklen_t namelen = sizeof(name);
        NSData *peer = nil;
        //这里是一个getpeername()函数的调用，这个函数有3个参数，第一个参数是一个已经连接的socket,这里就是nativeSocketHandle;
        //第二个参数是用来接收地址结构的，就是说这个函数从第一个参数的socket中获取与它捆绑的端口号和地址等信息，并把它存放在这第二个参数中；
        //第三个参数差不多了，它是取出这个socket的地址结构的数据长度放到这个参数里面。如果没有错误的话这个函数会返回0，
        //如果有错误的话会返回一个错误代码。这里判断了getpeername的返回值，没有错误的情况下，把得到的地址结构存储到我们申请的peer里。
        if (0 == getpeername(nativeSocketHandle, (struct sockaddr *)name, &namelen)) {
            peer = [NSData dataWithBytes:name length:namelen];
        }
        //申请了一对输入输出流，用CFStreamCreatePairWithSocket()方法把我们申请的这一对输入输出流和我们的已建立连接的socket（即现在的nativeSocketHandle）进行绑定，这样我们的这个连接就可以通过这一对流进行输入输出的操作了
        CFReadStreamRef readStream = NULL;
		CFWriteStreamRef writeStream = NULL;
        //两个输入输出流会被重新指向，使其指向有效的地址区域 ,参数一：内存分配器（苹果管理优化内存的一种措施，更多信息可网上查询）
        //参数二：就是想用我们第三和第四个参数代表的输入输出流的socket 参数三，参数四：绑定到第二个参数表示的socket的输入输出流的地址
        CFStreamCreatePairWithSocket(kCFAllocatorDefault, nativeSocketHandle, &readStream, &writeStream);
        //如果我们的CFStreamCreatePairWithSocket()方法操作成功的话，那么我们现在的readStream和writeStream应该指向有效的地址，而不是我们在刚申请时赋给的NULL了
        if (readStream && writeStream) {
            //把这两个流的属性kCFStreamPropertyShouldCloseNativeSocket设置为真，默认情况下这个属性是假的，这个设为真就是说，如果我们的流释放的话，我们这个流绑定的socket也要释放
            CFReadStreamSetProperty(readStream, kCFStreamPropertyShouldCloseNativeSocket, kCFBooleanTrue);
            CFWriteStreamSetProperty(writeStream, kCFStreamPropertyShouldCloseNativeSocket, kCFBooleanTrue);
            //通知viewcontroller
            [server handleNewConnectionFromAddress:peer inputStream:(NSInputStream *)readStream outputStream:(NSOutputStream *)writeStream];
        } else {
            //如果失败的话，我们就销毁着了已经连接的socket。
            // on any failure, need to destroy the CFSocketNativeHandle
            // since we are not going to use it any more
            close(nativeSocketHandle);
        }
        //这里是先对流的内容进行清空操作，防止在使用它们的时候，里面有我们不需要的垃圾数据。
        if (readStream) CFRelease(readStream);
        if (writeStream) CFRelease(writeStream);
    }
}
//创建端口监听
- (BOOL)start:(NSError **)error {
    //定义了一个CFSocketContext结构类型变量socketCtxt，并对这个结构进行初始化
    //该结构体有5个成员，第一个成员是这个结构的版本号，这个必需是0；第二个成员可以是一个你程序内定义的任何数据的指针，这里我们传入的是self，就是这们这个类本身了，
    //所以我们的TCPServerAcceptCallBack这个回调方法可以把它的info参数转成TCPServer，
    //并且这个参数会被传入在这个结构内定义的所有回调函数；第三、四、五这三个成员其实就是3个回调函数的指针，一般我们都设为NULL,就是不用它们。
    CFSocketContext socketCtxt = {0, self, NULL, NULL, NULL};
    
	// Start by trying to do everything with IPv6.  This will work for both IPv4 and IPv6 clients
    // via the miracle of mapped IPv4 addresses.
    //创建一个socket并把它赋给我们在TCPServer.h文件里定义的witap_socket变量.
    //CFSocketCreate有七个参数，参数一：一个内存分配器 参数二：要创建的socket的协议族（表明我们希望用IPv6协议），
    //参数三：表明我们是要数据流服务的，还有一种选择是数据报服务，这两种是基于不同的协议的，数据流是基于TCP/IP协议的，数据报是基于UDP协议的
    //参数四：们要创建的socket所用的具体的协议，这里我们传入IPPROTO_TCP 表明我们是遵守TCP/IP协议的
    //参数五：回调事件的类型，就是说当这个类型的事件发生时我们的回调函数会被调用，我们这里传入kCFSocketAcceptCallBack表明当连接成功里我们的回调会被触发。（这里可以设置不只一个回调事件类型，多个不同的事件类型用"|"(位或运算符)连起来就可以了
    // 比如类型为kCFSocketConnectCallBack，将会在连接成功或失败的时候在后台触发回调函数）
    //参数六：我们的回调函数的地址，当我们指定的回调事件出现时就调用这个回调函数，我们传入我们的TCPServerAcceptCallBack（）回调函数的地址;
    //参数七：一个结构指针，这个结构就是CFSocketContext类型，它保存socket的上下文信息，我们这里传入我们在注释1中定义的socketCtxt的地址。。（这个CFSocketCreate（）函数会拷贝一份这个结构的数据，所以在出了这个create函数之后，这个结构可以被置为NULL。）
    witap_socket = CFSocketCreate(kCFAllocatorDefault, PF_INET6, SOCK_STREAM, IPPROTO_TCP, kCFSocketAcceptCallBack, (CFSocketCallBack)&TCPServerAcceptCallBack, &socketCtxt);
	//判断这个witap_socket是否为空来判断我们刚才执行的socket创建工作有没有成功。
    if (witap_socket != NULL)	// the socket was created successfully
	{
		protocolFamily = PF_INET6;
	}
    //如果失败，使用IPv4协议
    else // there was an error creating the IPv6 socket - could be running under iOS 3.x
	{
		witap_socket = CFSocketCreate(kCFAllocatorDefault, PF_INET, SOCK_STREAM, IPPROTO_TCP, kCFSocketAcceptCallBack, (CFSocketCallBack)&TCPServerAcceptCallBack, &socketCtxt);
		if (witap_socket != NULL)
		{
			protocolFamily = PF_INET;
		}
	}
    
    if (NULL == witap_socket) { //如果都失败了
        //error是指向指针的指针，*error才是才是一个指向NSError类型的指针
        if (error) *error = [[NSError alloc] initWithDomain:TCPServerErrorDomain code:kTCPServerNoSocketsAvailable userInfo:nil];
        //如果这个witap_socket不为空，就把这个witap_socket释放了,感觉这段代码多余
        if (witap_socket) CFRelease(witap_socket);
        //之后把它设为NULL，防止野指针
        witap_socket = NULL;
        //返回一个NO，这是告诉我们的这个函数的调用都，我们创建socket失败了
        return NO;
    }
	
	
    int yes = 1;
    //调用setsockopt（）方法来设置socket的选项  ,参数一：一个socket的描述符，这里是通过CFSocketGetNative()方法来得到我们的socket对象针对于这个ios平台的描述符
    //参数二：选项定义的层次 支持SOL_SOCKET、IPPROTO_TCP、IPPROTO_IP和IPPROTO_IPV6 参数三：设置的选项的名字，这里是SO_REUSEADDR。（表示允许重用本地地址和端口，就是说充许绑定已被使用的地址（或端口号），
    //缺省条件下，一个套接口不能与一个已在使用中的本地地址捆绑。但有时会需要“重用”地址。因为每一个连接都由本地地址和远端地址的组合唯一确定，所以只要远端地址不同，两个套接口与一个地址捆绑并无大碍。）;
    //参数四：是一个指针，指向要设置的选项的选项值的缓冲区，这里是传入上面申请的int变量yes的地址，就是说我们把这个选项设为1
    //参数五：这个选项值数据缓冲区的大小，这里用sizeof得友yes的数据长度并传了进去。
    setsockopt(CFSocketGetNative(witap_socket), SOL_SOCKET, SO_REUSEADDR, (void *)&yes, sizeof(yes));
	
	// set up the IP endpoint; use port 0, so the kernel will choose an arbitrary port for us, which will be advertised using Bonjour
	if (protocolFamily == PF_INET6)
	{
        //申请一个sockaddr_in6的结构变量addr6，这个结构是一个IPv6协议的地址结构
		struct sockaddr_in6 addr6;
		memset(&addr6, 0, sizeof(addr6)); //用memset方法把这个刚申请的结构清零
		addr6.sin6_len = sizeof(addr6); //这个结构的大小
		addr6.sin6_family = AF_INET6; //协议
		addr6.sin6_port = 0; //端口号 设为0，那么在socket进行绑定操作的时候，系统会为我们分配一个任意可用的端口
		addr6.sin6_flowinfo = 0;//IPv6的流信息，sin6_flowinfo是与IPv6新增流标和流量类字段类相对应的一个选项，我们在编程时通常设为0
		addr6.sin6_addr = in6addr_any;//一个IN6_ADDR的结构，这个结构是真正存储我们的地址的    把这个地址结构的sin6_addr成员设置为in6addr_any 为填上这个值系统会自动为我们填上一个可用的本地地址
		NSData *address6 = [NSData dataWithBytes:&addr6 length:sizeof(addr6)]; //申请一个NSData变量address6把我们的地址结构addr6的信息进行拷贝存储
		//我们的witap_socket和上面刚设置好的地址address6进行绑定,如果绑定失败的话，就进行相应的清理工作并返回失败
		if (kCFSocketSuccess != CFSocketSetAddress(witap_socket, (CFDataRef)address6)) {
			if (error) *error = [[NSError alloc] initWithDomain:TCPServerErrorDomain code:kTCPServerCouldNotBindToIPv6Address userInfo:nil];
			if (witap_socket) CFRelease(witap_socket);
			witap_socket = NULL;
			return NO;
		}
		
		// now that the binding was successful, we get the port number
		// -- we will need it for the NSNetService
        //如果成功的话，就从这个绑定好的socket里拷贝出实际的地址并存储在addr6里
		NSData *addr = [(NSData *)CFSocketCopyAddress(witap_socket) autorelease];
        //void *memcpy(void *dest, const void *src, int n);函数的解释：从源src所指的内存地址的起始位置开始拷贝n个字节到目标dest所指的内存地址的起始位置中
        // 覆盖addr6原有的地址，我的理解是覆盖了addr6.sin6_addr的数据，不知道理解对不对
		memcpy(&addr6, [addr bytes], [addr length]);
        //ntohs:将一个无符号短整形数从网络字节顺序转换为主机字节顺序。 在TCPServer.h里定义的属性port设为系统为这个socket分配的实际的端口号，在后面发布NSNetService的时候需要用这个端口号
		self.port = ntohs(addr6.sin6_port);
		
	} else {
		struct sockaddr_in addr4;
		memset(&addr4, 0, sizeof(addr4));
		addr4.sin_len = sizeof(addr4);
		addr4.sin_family = AF_INET;
		addr4.sin_port = 0;
		addr4.sin_addr.s_addr = htonl(INADDR_ANY); //　将主机的无符号长整形数转换成网络字节顺序。
		NSData *address4 = [NSData dataWithBytes:&addr4 length:sizeof(addr4)];
		
		if (kCFSocketSuccess != CFSocketSetAddress(witap_socket, (CFDataRef)address4)) {
			if (error) *error = [[NSError alloc] initWithDomain:TCPServerErrorDomain code:kTCPServerCouldNotBindToIPv4Address userInfo:nil];
			if (witap_socket) CFRelease(witap_socket);
			witap_socket = NULL;
			return NO;
		}
		
		// now that the binding was successful, we get the port number
		// -- we will need it for the NSNetService
		NSData *addr = [(NSData *)CFSocketCopyAddress(witap_socket) autorelease];
		memcpy(&addr4, [addr bytes], [addr length]);
		self.port = ntohs(addr4.sin_port);
	}
	
    // set up the run loop sources for the sockets
    //申请了一个RunLoop的变量cfrl用来跟踪当前的RunLoop，通过CFRunLoopGetCurrent()方法得到当前线程正在运行的RunLoop，然后把它赋给cfrl;
    CFRunLoopRef cfrl = CFRunLoopGetCurrent();
    //创建了一个RunLoop的输入源变量source    CFSocketCreateRunLoopSource有三个参数  参数一：内存分配器  参数二：我们想要做为输入源来监听的socket对象 参数三：代表在RunLoop中处理这些输入源事件时的优先级，数小的话优先级高
    CFRunLoopSourceRef source = CFSocketCreateRunLoopSource(kCFAllocatorDefault, witap_socket, 0);
    //把这个输入源source加入到当前RunLoop来进行监测，CFRunLoopAddSource有三个参数 参数一：我们希望加入的RunLoop  参数二：入到第一个参数里的输入源  参数三：我们要加入的输入源要关联的模式
    //这里的kCFRunLoopCommonModes需要说明，这个kCFRunLoopCommonModes它并不是一个模式，苹果称它为伪模式，它其实是几个模式的合集，kCFRunLoopDefaultMode必定是
    //这个KCFRunLoopCommonModes的一个子集。你可以自己加入一些其它的模式到这个KCFRunLoopCommonModes里，这个通俗点解释怎么说呢，
    //比如说这个KCFRunLoopCommonModes里有两个子集，即有两个模式，我们假设是模式1和模式2，那么当我们把输入源关联到模式的时候传入
    //KCFRunLoopCommonModes的话，这个输入源就会和这两个模式，模式1和模式2，都进行关联，这样不管我们的RunLoop是以模式1运行的还是以模式2运行的，它都会监测我们的这个输入源）;
    CFRunLoopAddSource(cfrl, source, kCFRunLoopCommonModes);
    //加入了输入源之后RunLoop就自动保持了这个输入源，我们现在就可以释放这个输入源了
    CFRelease(source);
	//最后返回操作成功
    return YES;
}

- (BOOL)stop {
    //用它的disableBonjour方法来停止它的NSNetService服务的
    [self disableBonjour];
    //判断这个用来监听网络连接的socket是否有效，如果为真，就先把这个socket设为无效，再释放这个sockt资源，并把它置为NULL。
	if (witap_socket) {
		CFSocketInvalidate(witap_socket);
		CFRelease(witap_socket);
		witap_socket = NULL;
	}
	
	
    return YES;
}
//初始化服务需要的东西并发布服务
//这个方法有三个参数，它们都是我们用来发布NSNetService服务时要用的参数  参数一：发布服务用的域  参数二：要发布的网络服务的类型信息  参数三：用来表示我们这个服务的名字
- (BOOL) enableBonjourWithDomain:(NSString*)domain applicationProtocol:(NSString*)protocol name:(NSString*)name
{
	if(![domain length])
		domain = @""; //Will use default Bonjour registration doamins, typically just ".local"
	if(![name length])
		name = @""; //Will use default Bonjour name, e.g. the name assigned to the device in iTunes
	//如果参数protocol，即服务的协议，如果它不存在，或者它的字符长度为0，又或者witap_socket为NULL(也就是说我们这个用来监听的socket无效的话),直接返回失败
	if(!protocol || ![protocol length] || witap_socket == NULL)
		return NO;
	
    //初始化一个NSNetService服务，并把它赋给在TCPServer.h里定义的netService属性
    //	initWithDomain:domain有四个参数
    //参数一：它代表我们发布服务用的域，本地域是用@"local."来表示的，但是当我们想用本地域的时候，是不用直接传这个@"local."字符串进去的，我们只要传@""进去就行了，系统会自己把它按成本地域来使用的；
    //参数二:   这个网络服务的类型，这个类型必需包含服务类型和传输层信息（传输层概念请参考TCP/IP协议），这个服务类型的名字和传输层的名字
    //都要有“_”字符作为前缀。比如这个例子的服务类型的完整的名字其实是@"_witap._tcp."，看到了吧，它们都有前缀"_"，这里还有一点是要强调的，在这字符串结尾的"."符号是必需的，它表示这个域名字是绝对的
    //参数三：这个服务的名字，这个名字必需是唯一的，如果这个名字是@""的话，系统会自动把设备的名字作为这个服务的名字
    //参数四： 是端口号，这是我们发布这个服务用的。这个端口号必须是在应用程序里为这个服务获得的，这里就是witap_socket在绑定时我们获得的那个端口号，获得之后赋给了port属性，所以这里传入的是self.port。
    int f=self.port;
    
    self.netService = [[NSNetService alloc] initWithDomain:domain type:protocol name:name port:self.port];
    //判断这个netService属性是否有效来判断这个NSNetService的初始化是否成功。如果初始化失败的话，直接返回操作失败。
    if(self.netService == nil)
		return NO;
	//把这个netService加入到当前RunLoop中，并关联到相应的模式
	[self.netService scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
    //	发布我们的服务
    [self.netService publish];
    //设置这个netService的委托为这个TCPService类本身
	[self.netService setDelegate:self];
	
	return YES;
}

/*
 Bonjour will not allow conflicting service instance names (in the same domain), and may have automatically renamed
 the service if there was a conflict.  We pass the name back to the delegate so that the name can be displayed to
 the user.
 See http://developer.apple.com/networking/bonjour/faq.html for more information.
 */
//这是NSNetServiceDelegate协议的方法，服务发布成功后，调用这个方法
- (void)netServiceDidPublish:(NSNetService *)sender
{   //这里的self的委托被设置为AppController了，所以这里是判断AppController是不是响应这个serverDidEnableBonjour:withName方法，如果响应就对它调用这个方法
    if (self.delegate && [self.delegate respondsToSelector:@selector(serverDidEnableBonjour:withName:)])
		[self.delegate serverDidEnableBonjour:self withName:sender.name];
}
// 发布失败方法和这个成功方法基本上一样，不同的只是对应的方法，也不再重复说明了。
- (void)netService:(NSNetService *)sender didNotPublish:(NSDictionary *)errorDict
{
	if (self.delegate && [self.delegate respondsToSelector:@selector(server:didNotEnableBonjour:)])
		[self.delegate server:self didNotEnableBonjour:errorDict];
}
//停止NSNetService服务
- (void) disableBonjour
{
	if (self.netService) {
		NSLog(@"about to call NetService:stop");
	  	//停止这个服务
        [self.netService stop];
        //把它从RunLoop里移除使其不再被监听（NSNetService也是需要加入RunLoop来进行监测的），
		[self.netService removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
        //	这个netService置为NULL
        self.netService = nil;
	}
}
//帮助我们调试程序时方便用的，它把这个类的信息返回给我们，方便我们输出到控制台进行查看。它把这个TCPService类对象的类名，地址，port属性，netService属性都返回了，非常方便。
- (NSString*) description
{
	return [NSString stringWithFormat:@"<%@ = 0x%08X | port %d | netService = %@>", [self class], (long)self, self.port, self.netService];
}
//辅助方法 用途就是通过传入在AppController.m中定义的宏kGameIdentifier，然后返回一个完整的事实上的NSNetService的初始化方法中用的网络服务的类型
+ (NSString*) bonjourTypeFromIdentifier:(NSString*)identifier {
	if (![identifier length])
		return nil;
    
    return [NSString stringWithFormat:@"_%@._tcp.", identifier];
}

@end
