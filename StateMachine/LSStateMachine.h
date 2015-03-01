#import <Foundation/Foundation.h>
#import "LSStateMachineTypedefs.h"

@class LSEvent;

@interface LSStateMachine : NSObject
@property (nonatomic, strong, readonly) NSSet *states;
@property (nonatomic, strong, readonly) NSSet *events;
@property (nonatomic, strong) NSString *initialState;
@property (nonatomic, strong) NSString *finalState;



- (void)addState:(NSString *)state;
- (void)addCompoundState:(NSString *)state within:(NSString *)state;
-(void)setEntryPoint:(NSString *)state;
-(void)setExitPoint:(NSString *)state;


- (void)when:(NSString *)eventName guard:(BOOL)guard transitionFrom:(NSString *)from to:(NSString *)to;



- (LSEvent *)eventWithName:(NSString *)name;

- (void)before:(NSString *)eventName do:(LSStateMachineTransitionCallback)callback;
- (void)after:(NSString *)eventName do:(LSStateMachineTransitionCallback)callback;
- (void)self:(NSString *)eventName do:(LSStateMachineTransitionCallback)callback;



- (NSString *)nextStateFrom:(NSString *)from forEvent:(NSString *)event;

@end
