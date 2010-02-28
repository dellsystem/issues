/*
 * IssuesController.j
 * GitIssues
 *
 * Created by Randall Luecke on February 20, 2010.
 * Copyright 2010, Randall Luecke All rights reserved.
 *
*/

@implementation IssuesController : CPObject
{
    CPJSONPConnection   downloadIssuesConnection;
    CPJSONPConnection   downloadCommentsConnection;
    CPJSONPConnection   downloadTagsConnection;
    id                  appController @accessors;
    IssueView           issueView @accessors;
    CPArray             theIssues;
    CPArray             visibleIssues;
    CPDictionary        activeIssue @accessors;
    CPString            activeRepo @accessors;
    AjaxSeries          requests;

    /*
        search filter values:
        0: all
        1: title
        2: body
    */
    unsigned            searchFilter;
    CPString            searchValue;
}
- (id)init
{
    self = [super init];

    if(self)
    {
        requests = [[AjaxSeries alloc] initWithDelegate:self];
        visibleIssues = [CPArray array];
    }

    return self;
}

- (void)allIssuesForRepo:(CPString)theRepo user:(id)theUser
{
    var theReadURL = "https://" + GITHUBUSERNAME + ":" + GITHUBPASSWORD + "@github.com/api/v2/json/issues/list/" + theUser + "/" + theRepo + "/open",
        theRequest = [[CPURLRequest alloc] initWithURL:theReadURL];

    //[requests addReqeust theRequest];
    downloadIssuesConnection = [[CPJSONPConnection alloc] initWithRequest:theRequest callback:@"callback" delegate:self startImmediately:YES];
}

- (void)allTagsForRepo:(CPString)theRepo user:(id)theUser
{
    //var theReadURL = "https://github.com/api/v2/json/issues/labels/" + theUser + "/" + theRepo + "?login=" + GITHUBUSERNAME + "&token=" + GITHUBAPITOKEN,  
    var theReadURL = "https://" + GITHUBUSERNAME + ":" + GITHUBPASSWORD + "@github.com/api/v2/json/issues/labels/" + theUser + "/" + theRepo,
        theRequest = [[CPURLRequest alloc] initWithURL:theReadURL];
    //console.log(theReadURL);
    //[requests addReqeust theRequest];
    downloadTagsConnection = [[CPJSONPConnection alloc] initWithRequest:theRequest callback:@"callback" delegate:self startImmediately:YES];
}

- (void)commentsForActiveIssue 
{
    //console.log(activeRepo);
    //this is the issue number not the index btw
     var theUser = [activeRepo valueForKey:@"owner"],
         anIssueNumber = [activeIssue valueForKey:@"number"],
         repo = [activeRepo valueForKey:@"name"],
         getCommentsURL = "https://" + GITHUBUSERNAME + ":" + GITHUBPASSWORD + "@github.com/api/v2/json/issues/comments/" + theUser + "/" + repo + "/" + anIssueNumber,
         getCommentsRequest = [[CPURLRequest alloc] initWithURL:getCommentsURL];
    //console.log(getCommentsURL);
    downloadCommentsConnection = [[CPJSONPConnection alloc] initWithRequest:getCommentsRequest callback:@"callback" delegate:self startImmediately:YES];
}

/*Source list Delegates*/
- (void)tableViewSelectionDidChange:(id)notification
{
    var index = [[[notification object] selectedRowIndexes] firstIndex];
    activeIssue = [theIssues objectAtIndex:index];
    [self commentsForActiveIssue];
    [issueView setIssue:activeIssue];
}

- (id)tableView:(CPTableView)aTableView objectValueForTableColumn:(int)aColumn row:(int)aRow
{
    var column = [aColumn identifier],
        issue  = [visibleIssues objectAtIndex:aRow],
        value = [issue valueForKey:column];
    
    //special cases
    if(column === @"created_at" || column === @"updated_at")
        value = [CPDate simpleDate:value];

    return value;
}

- (int)numberOfRowsInTableView:(CPTableView)aTableView
{
    return [visibleIssues count];
}

- (void)tableView:(CPTableView)aTableView sortDescriptorsDidChange:(CPArray)oldDescriptors
{   
    var newDescriptors = [aTableView sortDescriptors];

    [theIssues sortUsingDescriptors:newDescriptors];
    [self searchFieldDidChange:nil];

	[aTableView reloadData];

    [aTableView selectRowIndexes:[CPIndexSet indexSetWithIndex:[theIssues indexOfObject:activeIssue]] byExtendingSelection:NO];
}

/*
    connection delegates
*/

-(void)connection:(CPURLConnection)connection didFailWithError:(id)error
{
    alert("There was a fail!");
}

-(void)connection:(CPURLConnection)connection didReceiveData:(CPString)data
{
    //we're looking for a json object back but we might get a stringified json object
    //console.log(typeof(data));
    //if(typeof(data) === "string")
      //  data = JSON.parse(data);
    if(data.error)
    {
        alert("An error has occured, check the console dude.");
        console.log(data.error);
        return;
    }
    
    if(connection === downloadIssuesConnection)
    {
        // from here we've got a json object of all the issues need to be displayed
        // once parsed display update the table
        theIssues = [CPArray array];

        for (var i = 0; i < data.issues.length; i++)
        //@each(var issue in data.issues)
        {
            var issue = data.issues[i];
            var anIssue = [CPDictionary dictionaryWithJSObject:issue recursively:NO];
            [theIssues addObject:anIssue];
        }
        visibleIssues = [CPArray arrayWithArray:theIssues];
        [self searchFieldDidChange:nil];
        [[appController issuesTable] reloadData];
    }
    else if(connection === downloadCommentsConnection)
    {
        //alert("you have comments, check the console dude.");
        //console.log(data);
        var theComments = [CPArray array];
        for (var i = 0; i < data.comments.length; i++)
        //@each(var comment in data.comments)
        {
            var comment = data.comments[i];
            var aComment = [CPDictionary dictionaryWithJSObject:comment recursively:NO];
            [theComments addObject:aComment];
        }
        [issueView setComments:theComments];
    }
    else if(connection === downloadTagsConnection)
    {
        //console.log(data);
        // here we have a list of all the labels. 
        // we then update the menu to display only those specific tags
        //tags = data.labels;
        //console.log(tags);
        //[appController updateTagsButtonWithTags:tags];
    }
}
@end

@implementation IssuesController (search)
- (void)searchFieldDidChange:(id)sender
{
    if(sender)
        searchValue = [sender stringValue];
    
    //console.log(sender);
    if (searchValue)
    {
        searchValue = [searchValue lowercaseString];
        [appController showSearchFilter];
        [visibleIssues removeAllObjects];
    }
    else
    {
        [appController hideSearchFilter];
        visibleIssues = [CPArray arrayWithArray:theIssues];
        [[appController issuesTable] reloadData];
        return;
    }

    for (var i = 0; i < [theIssues count]; i++)
    {
        var item = [theIssues objectAtIndex:i];

        // FIX ME: This is really bad... 
        if (searchFilter === 0 || searchFilter === 1 && [[item valueForKey:@"title"] lowercaseString].match(searchValue))
        {
            [visibleIssues addObject:[theIssues objectAtIndex:i]];
            // we continue to avoid duplicates if "all" is selected.
            continue;
        }

        if (searchFilter === 0 || searchFilter === 2 && [[item valueForKey:@"body"] lowercaseString].match(searchValue))
        {
            [visibleIssues addObject:[theIssues objectAtIndex:i]];
        }
    }

    [[appController issuesTable] reloadData];
}

- (void)filterDidChange:(id)sender
{
    searchFilter = [sender tag];
    [self searchFieldDidChange:nil];
}
@end