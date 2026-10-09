#import <Foundation/Foundation.h>
#include <assert.h>
#include <stdio.h>
#define SDL_max(a, b) ((a) > (b) ? (a) : (b))
#define SDL_min(a, b) ((a) < (b) ? (a) : (b))
static size_t SDL_utf8strlen(const char *text)
{
    size_t count = 0;
    while (*text) {
        if (((unsigned char)*text & 0xC0) != 0x80) ++count;
        ++text;
    }
    return count;
}
@interface UITextPosition : NSObject
@property NSInteger index;
@end
@implementation UITextPosition
@end
@interface UITextRange : NSObject
@property UITextPosition *start;
@property UITextPosition *end;
@end
@implementation UITextRange
@end
@interface SDLUITextField : NSObject
@property UITextRange *markedTextRange;
@property UITextRange *selectedTextRange;
@property NSString *text;
- (NSString *)textInRange:(UITextRange *)range;
- (NSInteger)offsetFromPosition:(UITextPosition *)start toPosition:(UITextPosition *)end;
@end
@implementation SDLUITextField
- (NSString *)textInRange:(UITextRange *)range
{
    return [self.text substringWithRange:NSMakeRange(range.start.index, range.end.index - range.start.index)];
}
- (NSInteger)offsetFromPosition:(UITextPosition *)start toPosition:(UITextPosition *)end
{
    return end.index - start.index;
}
@end
static NSString *eventText;
static int eventStart, eventLength;
static void SDL_SendEditingText(const char *text, int start, int length)
{
    eventText = @(text);
    eventStart = start;
    eventLength = length;
}
@interface CompositionController : NSObject {
    SDLUITextField *textField;
    BOOL hasMarkedText;
}
- (instancetype)initWithTextField:(SDLUITextField *)field;
- (void)textChanged;
@end
@implementation CompositionController
- (instancetype)initWithTextField:(SDLUITextField *)field
{
    self = [super init];
    if (self) textField = field;
    return self;
}
- (void)textChanged
{
/* PRODUCTION_MARKED_TEXT */
}
@end
static UITextRange *Range(NSInteger start, NSInteger end)
{
    UITextRange *range = [UITextRange new];
    range.start = [UITextPosition new];
    range.start.index = start;
    range.end = [UITextPosition new];
    range.end.index = end;
    return range;
}
int main(void)
{
    @autoreleasepool {
        SDLUITextField *field = [SDLUITextField new];
        field.text = @"prefixA😀한suffix";
        field.markedTextRange = Range(6, 10);
        CompositionController *controller = [[CompositionController alloc] initWithTextField:field];
        field.selectedTextRange = Range(9, 9); // After supplementary-plane emoji.
        [controller textChanged];
        assert([eventText isEqualToString:@"A😀한"]);
        assert(eventStart == 2 && eventLength == 0);
        field.selectedTextRange = Range(7, 9); // Select one emoji, two UTF-16 units.
        [controller textChanged];
        assert(eventStart == 1 && eventLength == 1);
        field.selectedTextRange = Range(9, 10); // Korean scalar after the emoji.
        [controller textChanged];
        assert(eventStart == 2 && eventLength == 1);
        field.selectedTextRange = nil;
        [controller textChanged];
        assert(eventStart == 0 && eventLength == 0);
        printf("PASS composition Unicode cursor/selection offsets\n");
    }
    return 0;
}
