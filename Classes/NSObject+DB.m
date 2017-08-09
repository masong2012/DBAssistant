//
//  NSObject+DB.m
//  Baitu
//
//  Created by MaSong on 2016/12/17.
//  Copyright © 2016年 MaSong. All rights reserved.
//

#import "NSObject+DB.h"
#import "NSObject+DBCallback.h"

static char FMDBModelKeyRowID;
static char FMDBModelKeyTableName;

@implementation NSObject (DB)

+(NSString *)defaultDBDirPath{
    NSString *docPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
    return docPath;
}


+(NSString *)defaultDBPath{
    NSString *dbsPath = [NSFileManager createDirInDocument:@"databases"];
    NSString* dbPath = [dbsPath stringByAppendingPathComponent:@"defaultDB.db"];
    return dbPath;
}

+(DBAssistant *)currentDBAssistant{
    static __strong NSMutableDictionary* onceDBAssistants;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        onceDBAssistants = [NSMutableDictionary new];
    });
    
    NSString *dbPath = [self dbPath];
    if ([dbPath isEmpty]) {
        dbPath = [self defaultDBPath];
    }
    
    NSString *key = [dbPath md5String];
//    NSString *key = NSStringFromClass(self);
    DBAssistant* assistant = [onceDBAssistants objectForKey:key];
    
    if (assistant == nil) {

        assistant = [[DBAssistant alloc]initWithDBPath:dbPath];
        if (assistant == nil) {
            NSAssert(0, @"DBAssistant is nil ....");
        } else {
            [onceDBAssistants setObject:assistant forKey:key];
        }
    }
    
    return assistant;
}

#pragma mark -
+(NSString*)dbPath{
    return [self defaultDBPath];
}

+ (NSString *)tableName{
    return NSStringFromClass(self);
}

+(NSArray*)primaryKeys{
    return @[DBRowId];
}

+(NSArray *)onlyPropertiesToMapColumns{
    return nil;
}

+(NSArray *)exceptPropertiesToMapColumns{
    return nil;
}

+(NSDictionary *)propertyToColumnMappings{
    return nil;
}

+(NSDictionary *)defaultValues{
    return nil;
}

+(NSDictionary *)checkValues{
    return nil;
}

+(NSDictionary *)lengthValues{
    return nil;
}

+(NSArray *)uniqueValues{
    return nil;
}

+(NSArray *)notNullValues{
    return nil;
}


+(BOOL)shouldMapAllParentPropertiesToTable{
    return NO;
}

+(BOOL)shouldMapAllSelfPropertiesToTable{
    return YES;
}




+(NSString *)dateFormatterString{
    return nil;
}


+(NSString *)imagePathForImage:(NSString *)imgName {
    
    NSString* appendingDir = [NSFileManager createDirInDocument:[NSString stringWithFormat:@"dbimg/%@",NSStringFromClass(self)]];
    
    return [appendingDir stringByAppendingPathComponent:imgName];
}

+(NSString*)dataPathForData:(NSString *)dataName {
    
    NSString* appendingDir = [NSFileManager createDirInDocument:[NSString stringWithFormat:@"dbdata/%@",NSStringFromClass(self)]];
    
    return [appendingDir stringByAppendingPathComponent:dataName];
}



+(BOOL)createTable{
    return [[self currentDBAssistant] createTable:[self tableName] forClass:self];
}


+(BOOL)dropTable{
    return [[self currentDBAssistant] dropTableForClass:self];
}

+(BOOL)insertModel:(NSObject *)model{
    return [[self currentDBAssistant] insertModel:model intoTable:[self tableName] forClass:self];
}


+(BOOL)insertModelIfNotExists:(NSObject *)model{
    return [[self currentDBAssistant] insertModelIfNotExists:model intoTable:[self tableName] forClass:self];
}


+(BOOL)deleteModel:(NSObject *)model{
    return [[self currentDBAssistant] deleteModel:model fromTable:[self tableName] forClass:self];
}


+(BOOL)deleteModelsWhere:(NSObject *)where{
    return [[self currentDBAssistant] deleteModelsFromTable:[self tableName] where:where forClass:self];
}


+(BOOL)updateModelsWithModel:(NSObject *)model where:(NSObject *)where{
    return [[self currentDBAssistant] updateTable:[self tableName] withModel:model where:where forClass:self];
}


+(BOOL)updateModelsWithDictionary:(NSDictionary *)dic where:(NSObject *)where{
    return [[self currentDBAssistant] updateTable:[self tableName] withKeysAndValues:dic where:where forClass:self];
}

+(BOOL)modelExists:(NSObject *)model{
    return [[self currentDBAssistant] modelExists:model inTable:[self tableName] forClass:self];
}


+(id)firstModelWhere:(NSObject *)where{
    
    return [self firstModelWhere:where orderBy:nil];
}

+(id)firstModelWhere:(NSObject *)where orderBy:(NSString*)orderBy{
    return [[self currentDBAssistant] firstModelFromTable:[self tableName] where:where orderBy:orderBy forClass:self];
}

+(id)lastModel{
    return [[self currentDBAssistant] lastModelFromTable:[self tableName] forClass:self];
}



+(NSArray *)allModels{
    return [self findModelsWhere:nil];
}

+(NSArray *)findModelsWhere:(NSObject *)where{
    return [self findModelsWhere:where groupBy:nil orderBy:nil limit:0 offset:0];
}

+(NSArray *)findModelsWhere:(NSObject *)where orderBy:(NSString *)orderBy{
    return [self findModelsWhere:where groupBy:nil orderBy:orderBy limit:0 offset:0];
}

+(NSArray *)findModelsWhere:(NSObject *)where groupBy:(NSString *)groupBy orderBy:(NSString*)orderBy limit:(int)limit offset:(int)offset {
    return [[self currentDBAssistant] selectModelsFromTable:[self tableName] where:where groupBy:groupBy orderBy:orderBy limit:limit offset:offset forClass:self];
}

+ (NSArray *)findModelsBySQL:(NSString *)sql{
    
    NSString *table_name = tableNameForClass([self tableName], self);
    if (table_name == nil) {
        return nil;
    }
    __block NSMutableArray* result = nil;
    [[self currentDBAssistant] executeDB:^(FMDatabase *db){
        
        FMResultSet *rs = nil;
        
        rs = [db executeQuery:sql ];
        
        result = [[self currentDBAssistant] progressResultSet:rs forTable:[self tableName] targetClass:self];
        [rs close];
    }];
    
    return result;
}

+ (NSInteger)rowCountWhere:(NSObject *)where{
    return [[self currentDBAssistant] rowCountOfTableName:[self tableName] where:where forClass:self];
}

#pragma mark -
#pragma mark - instance methods


- (void)setRow_id:(NSUInteger)row_id{
    setAssociatedObject(self, &FMDBModelKeyRowID, @(row_id));
}

- (NSUInteger)row_id{
    return [getAssociatedObject(self, &FMDBModelKeyRowID) unsignedIntegerValue];
}

- (void)setTable_name:(NSString *)table_name{
    if ([table_name isNotEmpty]) {
        setAssociatedObject(self, &FMDBModelKeyTableName, table_name);
    }
}

- (NSString *)table_name{
    return getAssociatedObject(self, &FMDBModelKeyTableName) ?: [self.class tableName];
}




- (BOOL)saveModel{
    
    if(self.row_id > 0){
        return [self.class updateModelsWithModel:self where:@{DBRowId : @(self.row_id)}];
    } else {
        return [self.class insertModel:self];
    }
}

- (BOOL)deleteModel{
    return [self.class deleteModel:self];
}

- (BOOL)updateModel:(id)value{
    if (value) {
        if([value isKindOfClass:[NSDictionary class]]){
            
            if (![self.class shouldUpdate:self]) {
                return NO;
            }
            
            [self.class modelWillUpdate:self];
            
            BOOL res = [self.class updateModelsWithDictionary:value where:indicatorForModel(self)];
            
            for(NSString *property in [value allKeys]){
                id v = [value valueForKey:property];
                if (v) {
                    [self setValue:v forKey:property];
                }
            }
            
            [self.class modelDidUpdate:self result:res] ;
            
            return res;
        } else{
            return [self.class updateModelsWithModel:value where:indicatorForModel(self)];
        }
    }
    return NO;
}


+ (void)beginTransaction{
    [[self currentDBAssistant] beginTransaction];
}

+ (void)commit{
    [[self currentDBAssistant] commit];
}

+ (void)rollback{
    [[self currentDBAssistant] rollback];
}
@end


