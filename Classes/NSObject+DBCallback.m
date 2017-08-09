//
//  NSObject+DBCallback.m
//  Note
//
//  Created by MaSong on 2017/5/25.
//  Copyright © 2017年 MaSong. All rights reserved.
//

#import "NSObject+DBCallback.h"

@implementation NSObject (DBCallback)
+ (BOOL)shouldInsert:(NSObject *)model{
    return YES;
}
+ (void)modelWillInsert:(NSObject *)model{
    
}
+ (void)modelDidInsert:(NSObject *)model result:(BOOL)result{
    
}

+ (BOOL)shouldDelete:(NSObject *)model{
    return YES;
}
+ (void)modelWillDelete:(NSObject *)model{
    
}
+ (void)modelDidDelete:(NSObject *)model result:(BOOL)result{
    
}

+ (BOOL)shouldUpdate:(NSObject *)model{
    return YES;
}
+ (void)modelWillUpdate:(NSObject *)model{
    
}
+ (void)modelDidUpdate:(NSObject *)model result:(BOOL)result{
    
}

@end
