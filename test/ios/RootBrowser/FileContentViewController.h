#import <UIKit/UIKit.h>

#import "SearchViewController.h"

@class FileContainerElement;
@class ObjectShortcutView;

namespace ROOT {
namespace iOS {
namespace Browser {

class FileContainer;

}
}
}

@interface FileContentViewController : UIViewController <UISearchBarDelegate, UIPopoverControllerDelegate, SearchViewDelegate> {
@private
   ROOT::iOS::Browser::FileContainer *fileContainer;
   __weak IBOutlet UIScrollView *scrollView;
}

//@property (nonatomic, assign) id<UITableViewDataSource> *
@property (nonatomic, readonly) ROOT::iOS::Browser::FileContainer *fileContainer;

- (void) activateForFile : (ROOT::iOS::Browser::FileContainer *)container;
- (void) selectObjectFromFile : (ObjectShortcutView *)obj;

- (void) searchesController : (SearchViewController *) controller didSelectKey : (FileContainerElement *) key;

@end
