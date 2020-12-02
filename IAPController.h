/**
 MIT License
 
 Copyright (c) 2018 Scott Ban (https://github.com/reference/BDToolKit)
 
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in all
 copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 SOFTWARE.
 */
#import <Foundation/Foundation.h>

typedef enum{
    kIAPPurchSuccess = 0,      // 购买成功
    kIAPPurchFailed = 1,       // 购买失败
    kIAPPurchCancle = 2,       // 取消购买
    kIAPPurchVerFailed = 3,    // 订单校验失败
    kIAPPurchVerSuccess = 4,   // 订单校验成功
    kIAPPurchNotArrow = 5,     // 不允许内购
}  IAPPurchType;

typedef void(^IAPCompletionHandle)(IAPPurchType type,NSData *data);

@interface IAPController : NSObject

- (void)startPurchWithID:(NSString *)purchID serverId:(NSString *)sid extraStr:(NSString *)extra completeHandle:(IAPCompletionHandle)handle;

@end
