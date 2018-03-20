/* DO NOT TOUCH THIS EMBEDS IRIDIZE ON THE PAGE */
/* Iridize.com*/
window.iridize = window.iridize || function(e, t, n) {
    return iridize.api.call(e, t, n);
};
iridize.api = iridize.api || {
    q: [],
    call: function(e, t, n) {
        iridize.api.q.push({
            method: e,
            data: t,
            callback: n
        });
    }
};
iridize.appId = "W9Lssne1QZuHNQyX4zyR2g";
iridize.env = "dev";
(function() {
    var e = document.createElement("script");
    var t = document.getElementsByTagName("script")[0];
    e.src = ("https:" == document.location.protocol ? "https:" : "http:") + "//d2p93rcsj9dwm5.cloudfront.net/player/latest/static/js/iridizeLoader.min.js";
    e.type = "text/javascript";
    e.async = true;
    t.parentNode.insertBefore(e, t);
})();




/**
 * closes the overlay modal, and reset all states
 */
function closeModal() {
    var fullOverlay, searchBox;
    fullOverlay = document.getElementById("overlayId");
    fullOverlay.className = "hidden";
    searchBox = document.getElementById("searchBox");
    searchBox.value = '';
    $("#guidesList").empty();
}


/**
 * initialize html tags and elements in the search window
 */
function createSearchWindow() {
    var searchWindow, closeBtn;

    searchWindow = document.createElement("div");

    searchWindow.id = "searchWindowId";
    searchWindow.setAttribute("class", "hidden");
    // createMainScreen(searchWindow);
    closeBtn = document.createElement("span");
    closeBtn.setAttribute("class", "closeButton");
    closeBtn.innerHTML = "&times;";
    var windowTitle = document.createElement("h1");
    windowTitle.innerHTML = "Seach Iridize Guides:";
    searchWindow.appendChild(closeBtn);
    searchWindow.appendChild(windowTitle);
    // event listener when clicking on the close button
    closeBtn.addEventListener("click", closeModal);

    setSearchGuides(searchWindow);
    return searchWindow;
}

/**
 * Creates the search box and calls the function that creates the list of results
 * @param searchWindow the main modal overlay on which we add the input field and list of results
 */
function setSearchGuides(searchWindow) {
    var searchBoxDiv, searchBox;
    // A function that will set the delay time to be only once in the stated time
    var searchBoxDelay = (function() {
        var timer = 0;
        return function(callback, ms) {
            clearTimeout(timer);
            timer = setTimeout(callback, ms);
        };
    })();

    // create the search box and add use the searchBoxDelay function
    searchBoxDiv = document.createElement("div");
    searchBox = document.createElement("input");
    searchBox.setAttribute("placeholder", " Search");
    searchBoxDiv.appendChild(searchBox);
    searchWindow.appendChild(searchBoxDiv);
    searchBox.setAttribute("type", "text");
    searchBox.id = "searchBox";

    typeInSearchBox(searchBoxDiv, searchBox, searchBoxDelay);

}

/**
 * gets the element of the result link in the main screen,
 * adds to it the permalink to the guide and closes the modal
 * @param guide - the object that we will return its permalink to the user
 */
function returnPermalink(guide) {
    var resultLink = document.getElementById("resultLink");
    var resultLinkDiv = document.getElementById("resultLinkDiv");
    resultLinkDiv.setAttribute("class", "unhidden");
    resultLink.href = guide.startUrl + guide.apiName;
    resultLink.title = "peramlink to guide";
    resultLink.text = "click on the link to enter guide";

    closeModal();
}


/**
 * create for every guide that is supposed to appear in the search result
 * a div with the guide name as a link and description
 * @param guide
 */
function buildDivForList(guide) {
    var listVal, listLink, listP, list, li;
    listVal = document.createElement("div");
    listLink = document.createElement("p");
    listP = document.createElement("p");
    li = document.createElement("li");
    list = document.getElementById("guidesList");

    listLink.appendChild(document.createTextNode(guide.displayName));
    listP.appendChild(document.createTextNode(guide.description));

    listVal.appendChild(listLink);
    listVal.appendChild(listP);
    listLink.id = "guideName";
    listLink.addEventListener("click", function() {
        returnPermalink(guide);
    });
    li.appendChild(listVal);
    list.appendChild(li);

}

/**
 * creates the list of results from the guides list.
 * It is done using the searchBoxDelay function(described below).
 * @param searchBoxDiv - the div of the search box
 * @param searchBox - the input field
 * @param searchBoxDelay - the function that creates a delay during type, so we won't make
 *                         a function call after every type
 */
function typeInSearchBox(searchBoxDiv, searchBox, searchBoxDelay) {
    var ul = document.createElement("ul");
    var ulDiv = document.createElement("div");
    ulDiv.id = "ulDiv";
    ulDiv.appendChild(ul);
    searchBoxDiv.appendChild(ulDiv);
    ul.id = "guidesList";
    searchBox.addEventListener("keyup", function() {
        searchBoxDelay(function() {
            // here I call the iridize's api.guide.list
            $(ul).empty();
            var searchVal = searchBox.value;
            iridize("api.guide.list", {}, function(data) {
                var guidesList, guide, i;
                // get the array of guide information objects
                guidesList = data.guides;
                for (i = 0; i < guidesList.length; i++) {
                    guide = guidesList[i];
                    // if the user didn't enter any text, don't search
                    if (searchVal == "") {
                        break;
                    }
                    if (guide.displayName.includes(searchVal) ||
                        guide.description.includes(searchVal)) {
                        buildDivForList(guide);
                    }
                }
            });
        }, 1000)
    });
}

/**
 * initialize html tags and elements in the main screen
 */
function createMainScreen() {
    var resultPermalinkDiv = document.createElement("div");
    var resultPermalink = document.createElement("a");
    resultPermalinkDiv.id = "resultLinkDiv";
    resultPermalink.id = "resultLink";
    resultPermalinkDiv.setAttribute("class", "hidden");

    resultPermalinkDiv.appendChild(resultPermalink);
    document.body.appendChild(resultPermalinkDiv);
}

/**
 * create the overlay on which the search window will appear
 */
function createOverlay() {
    var overlay = document.createElement("div");
    // document.getElementsByTagName("div")[0].setAttribute("class", "visible");
    overlay.id = "overlayId";
    overlay.setAttribute("class", "hidden");
    overlay.appendChild(createSearchWindow());
    document.body.appendChild(overlay);
}



var btn = document.getElementById("doit");
var closeBtn = document.getElementsByClassName("closeButton");

$(document).ready(function() {
    createMainScreen();
    createOverlay();



    $('#doit').click(function() {
        var fullOverlay = document.getElementById("overlayId");
        var searchWindow = document.getElementById("searchWindowId");
        if (fullOverlay.className === "hidden") {
            fullOverlay.className = "unhidden";
            if (searchWindow.className === "hidden") {
                searchWindow.className = "unhidden";
            }
        }

    });
});
