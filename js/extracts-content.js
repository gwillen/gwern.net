if (window.Extracts) {
	/*=---------------=*/
	/*= REMOTE VIDEOS =*/
	/*=---------------=*/

    Extracts.youtubeId = (href) => {
        let match = href.match(/^.*(youtu.be\/|v\/|u\/\w\/|embed\/|watch\?v=|\&v=)([^#\&\?]*).*/);
        if (match && match[2].length == 11) {
            return match[2];
        } else {
            return null;
        }
    };

    Extracts.isVideoLink = (target) => {
        if (!target.href) return false;

        if ([ "www.youtube.com", "youtube.com", "youtu.be" ].includes(target.hostname)) {
            return (Extracts.youtubeId(target.href) != null);
        } else {
            return false;
        }
    };

    Extracts.videoForTarget = (target) => {
        GWLog("Extracts.videoForTarget", "extracts-content.js", 2);

        let videoId = Extracts.youtubeId(target.href);
        let videoEmbedURL = `https://www.youtube.com/embed/${videoId}`;
        let placeholderImgSrc = `https://img.youtube.com/vi/${videoId}/hqdefault.jpg`;
        let srcdocStyles = `<style>` + 
            `* { padding: 0; margin: 0; overflow: hidden; }` + 
            `html, body { height: 100%; } ` + 
            `img, span { position: absolute; width: 100%; top: 0; bottom: 0; margin: auto; } ` + 
            `span { height: 1.5em; text-align: center; font: 48px/1.5 sans-serif; color: white; text-shadow: 0 0 0.5em black; }` + 
            `</style>`;
        let playButtonHTML = `<span class='video-embed-play-button'>&#x25BA;</span>`;
        let srcdocHTML = `<a href='${videoEmbedURL}?autoplay=1'><img src='${placeholderImgSrc}'>${playButtonHTML}</a>`;

        //  `allow-same-origin` only for EXTERNAL videos, NOT local videos!
        return `<iframe src="${videoEmbedURL}" srcdoc="${srcdocStyles}${srcdocHTML}" frameborder="0" allowfullscreen sandbox="allow-scripts allow-same-origin"></iframe>`;
    };

	/*=-----------------------=*/
	/*= LOCALLY HOSTED VIDEOS =*/
	/*=-----------------------=*/

	Extracts.isLocalVideoLink = (target) => {
		if (  !target.href
			|| target.hostname != location.hostname)
			return false;

		let videoFileURLRegExp = new RegExp(
			  '(' 
			+ Extracts.videoFileExtensions.map(ext => `\\.${ext}`).join("|") 
			+ ')$'
		, 'i');
		return (target.pathname.match(videoFileURLRegExp) != null);
	};

    Extracts.localVideoForTarget = (target) => {
		GWLog("Extracts.localVideoForTarget", "extracts-content.js", 2);

// 		let width = target.dataset.imageWidth || 0;
// 		let height = target.dataset.imageHeight || 0;
// 
// 		if (width > Extracts.imageMaxWidth) {
// 			height *= Extracts.imageMaxWidth / width;
// 			width = Extracts.imageMaxWidth;
// 		}
// 		if (height > Extracts.imageMaxHeight) {
// 			width *= Extracts.imageMaxHeight / height;
// 			height = Extracts.imageMaxHeight;
// 		}
// 
// 		let styles = ``;
// 		if (width > 0 && height > 0) {
// 			styles = `width="${width}" height="${height}" style="width: ${width}px; height: ${height}px;"`;
// 		}

        //  Note that we pass in the original image-link’s classes - this is good for classes like ‘invertible’.
//         return `<img ${styles} class="${target.classList}" src="${target.href}" loading="lazy">`;
        return `<video controls="controls" preload="none">` + 
        	`<source src="${target.href}">` + 
			`</video>`;
    };

	Extracts.preparePopup_LOCAL_VIDEO = (popup) => {
		popup.classList.add("mini-title-bar");	
	};

	Extracts.rewritePopFrameContent_LOCAL_VIDEO = (popFrame) => {
		//  Loading spinner.
		Extracts.setLoadingSpinner(popFrame);
	};

	/*=-----------------------=*/
	/*= LOCALLY HOSTED IMAGES =*/
	/*=-----------------------=*/

	Extracts.imageFileExtensions = [ "bmp", "gif", "ico", "jpeg", "jpg", "png", "svg" ];

    Extracts.isLocalImageLink = (target) => {
		if (  !target.href
			|| target.hostname != location.hostname)
			return false;

		let imageFileURLRegExp = new RegExp(
			  '(' 
			+ Extracts.imageFileExtensions.map(ext => `\\.${ext}`).join("|") 
			+ ')$'
		, 'i');
		return (target.pathname.match(imageFileURLRegExp) != null);
    };

    Extracts.localImageForTarget = (target) => {
		GWLog("Extracts.localImageForTarget", "extracts-content.js", 2);

		let width = target.dataset.imageWidth || 0;
		let height = target.dataset.imageHeight || 0;

		if (width > Extracts.imageMaxWidth) {
			height *= Extracts.imageMaxWidth / width;
			width = Extracts.imageMaxWidth;
		}
		if (height > Extracts.imageMaxHeight) {
			width *= Extracts.imageMaxHeight / height;
			height = Extracts.imageMaxHeight;
		}

		let styles = ``;
		if (width > 0 && height > 0)
			styles = `width="${width}" height="${height}" style="width: ${width}px; height: ${height}px;"`;

        //  Note that we pass in the original image-link’s classes - this is good for classes like ‘invertible’.
        return `<img ${styles} class="${target.classList}" src="${target.href}" loading="lazy">`;
    };

	Extracts.preparePopup_LOCAL_IMAGE = (popup) => {
		popup.classList.add("mini-title-bar");	
	};

	Extracts.rewritePopFrameContent_LOCAL_IMAGE = (popFrame) => {
		//  Remove extraneous classes from images in image pop-frames.
		popFrame.querySelector("img").classList.remove("has-annotation", "has-content", "link-self", "link-local");

		//  Loading spinner.
		Extracts.setLoadingSpinner(popFrame);
	};

	Extracts.rewritePopinContent_LOCAL_IMAGE = (popin) => {
		Extracts.rewritePopFrameContent_LOCAL_IMAGE(popin);

		//  Remove extraneous classes from images in image popins.
		popin.querySelector("img").classList.remove("spawns-popin");
	};

	Extracts.rewritePopupContent_LOCAL_IMAGE = (popup) => {
		Extracts.rewritePopFrameContent_LOCAL_IMAGE(popup);

		//  Remove extraneous classes from images in image popups.
		popup.querySelector("img").classList.remove("spawns-popup");

		if (popup.querySelector("img[width][height]"))
			popup.classList.add("dimensions-specified");
	};

	/*=--------------------------=*/
	/*= LOCALLY HOSTED DOCUMENTS =*/
	/*=--------------------------=*/

    Extracts.isLocalDocumentLink = (target) => {
		if (  !target.href
			|| target.hostname != location.hostname
			|| Extracts.isExtractLink(target))
			return false;

	    return (   target.pathname.startsWith("/docs/www/")
	            || (   target.pathname.startsWith("/docs/")
	                && target.pathname.match(/\.(html|pdf)$/i) != null));
    };

    Extracts.localDocumentForTarget = (target) => {
		GWLog("Extracts.localDocumentForTarget", "extracts-content.js", 2);

		if (target.href.match(/\.pdf(#|$)/) != null) {
			let data = target.href + (target.href.includes("#") ? "&" : "#") + "view=FitH";
			return `<object data="${data}"></object>`;
		} else {
			return `<iframe src="${target.href}" frameborder="0" sandbox="allow-same-origin" referrerpolicy="same-origin"></iframe>`;
		}
    };

	Extracts.rewritePopFrameContent_LOCAL_DOCUMENT = (popFrame) => {
		//  Set title of popup from page title.
		let iframe = popFrame.querySelector("iframe");
		if (iframe) {
			iframe.addEventListener("load", (event) => {
				popFrame.titleBar.querySelector(".popframe-title-link").innerHTML = iframe.contentDocument.title;
			});
		}

		//  Loading spinner.
		Extracts.setLoadingSpinner(popFrame);
	};

	/*=---------------------------=*/
	/*= LOCALLY HOSTED CODE FILES =*/
	/*=---------------------------=*/

    Extracts.isLocalCodeFileLink = (target) => {
		if (  !target.href
			|| target.hostname != location.hostname
			|| Extracts.isExtractLink(target))
			return false;

		let codeFileURLRegExp = new RegExp(
			  '(' 
			+ Extracts.codeFileExtensions.map(ext => `\\.${ext}`).join("|") 
			+ ')$'
		, 'i');
		return (target.pathname.match(codeFileURLRegExp) != null);
    };

	/*  We first try to retrieve a syntax-highlighted version of the given code 
		file, stored on the server as an HTML fragment. If present, we embed 
		that. If there’s no such fragment, then we just embed the contents of 
		the actual code file, in a <pre>-wrapped <code> element.
		*/
    Extracts.localCodeFileForTarget = (target) => {
		GWLog("Extracts.localCodeFileForTarget", "extracts-content.js", 2);

		let setPopFrameContent = Popups.setPopFrameContent;

		target.popFrame.classList.toggle("loading", true);
		doAjax({
			location: target.href + ".html",
			onSuccess: (event) => {
				if (!target.popFrame)
					return;

				target.popFrame.classList.toggle("loading", false);
				setPopFrameContent(target.popFrame, event.target.responseText);
			},
			onFailure: (event) => {
				doAjax({
					location: target.href,
					onSuccess: (event) => {
						if (!target.popFrame)
							return;

						target.popFrame.classList.toggle("loading", false);

						let htmlEncodedResponse = event.target.responseText.replace(/[<>]/g, c => ('&#' + c.charCodeAt(0) + ';'));
						let lines = htmlEncodedResponse.split("\n");
						htmlEncodedResponse = lines.map(line => `<span class="line">${(line || "&nbsp;")}</span>`).join("\n");

						setPopFrameContent(target.popFrame, `<pre class="raw-code"><code>${htmlEncodedResponse}</code></pre>`);
					},
					onFailure: (event) => {
						if (!target.popFrame)
							return;

						target.popFrame.swapClasses([ "loading", "loading-failed" ], 1);
					}
				});
			}
		});

		return `&nbsp;`;
    };

	/*=----------------=*/
	/*= OTHER WEBSITES =*/
	/*=----------------=*/

	Extracts.isForeignSiteLink = (target) => {
		if (  !target.href
			|| Extracts.isExtractLink(target)) return false;

		return  (   Extracts.qualifyingForeignDomains.includes(target.hostname)
				 || Extracts.qualifyingForeignDomains.findIndex(domainPattern => (domainPattern instanceof RegExp && domainPattern.test(target.hostname) == true)) != -1)
			&& !Extracts.blacklistedForeignDomains.includes(target.hostname);
	};

	Extracts.foreignSiteForTarget = (target) => {
		GWLog("Extracts.foreignSiteForTarget", "extracts-content.js", 2);

		let url = new URL(target.href);

		if ([ "www.lesswrong.com", "lesswrong.com", "www.greaterwrong.com", "greaterwrong.com" ].includes(url.hostname)) {
			url.protocol = "https:";
			url.hostname = "www.greaterwrong.com";
			url.search = "format=preview&theme=classic";
		} else if (/(.+?)\.wikipedia\.org/.test(url.hostname) == true) {
			url.protocol = "https:";
			url.hostname = url.hostname.replace(/(.+?)(?:\.m)?\.wikipedia\.org/, "$1.m.wikipedia.org");
			if (!url.hash)
				url.hash = "#bodyContent";
		} else {
			url.protocol = "https:";
		}

		return `<iframe src="${url.href}" frameborder="0" sandbox></iframe>`;
	};

	Extracts.rewritePopFrameContent_FOREIGN_SITE = (popFrame) => {
		//  Loading spinner.
		Extracts.setLoadingSpinner(popFrame);
	};
}
