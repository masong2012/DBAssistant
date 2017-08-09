//
//  User.h
//  Demo
//
//  Created by MaSong on 2017/8/9.
//  Copyright © 2017年 MaSong. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NSObject+DB.h"

@interface User : NSObject

@property (strong, nonatomic) NSString *name;
@property (assign, nonatomic) CGFloat height;
@property (assign, nonatomic) NSInteger num;


@end
