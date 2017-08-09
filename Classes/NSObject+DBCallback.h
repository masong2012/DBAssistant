//
//  NSObject+DBCallback.h
//  Note
//
//  Created by MaSong on 2017/5/25.
//  Copyright © 2017年 MaSong. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSObject (DBCallback)
+ (BOOL)shouldInsert:(NSObject *)model;
+ (void)modelWillInsert:(NSObject *)model;
+ (void)modelDidInsert:(NSObject *)model result:(BOOL)result;

+ (BOOL)shouldDelete:(NSObject *)model;
+ (void)modelWillDelete:(NSObject *)model ;
+ (void)modelDidDelete:(NSObject *)model result:(BOOL)result;

+ (BOOL)shouldUpdate:(NSObject *)model;
+ (void)modelWillUpdate:(NSObject *)model;
+ (void)modelDidUpdate:(NSObject *)model result:(BOOL)result;

@end
