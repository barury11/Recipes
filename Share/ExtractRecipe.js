var ExtensionPreprocessingJS = {
    run: function (arguments) {
        var readMeta = function (name) {
            var element = document.querySelector('meta[property="' + name + '"],meta[name="' + name + '"]');
            return element ? element.content.slice(0, 4096) : "";
        };
        var blocks = [];
        var remaining = 420000;
        document.querySelectorAll('script[type="application/ld+json"]').forEach(function (element) {
            var data = element.textContent;
            if (/"(?:schema:)?Recipe"/i.test(data) && data.length <= remaining && blocks.length < 16) {
                blocks.push(data);
                remaining -= data.length;
            }
        });

        var root = document.querySelector('main article, [role="main"] article, article, main, [role="main"]') || document.body;
        var content = root ? root.cloneNode(true) : null;
        if (content) {
            content.querySelectorAll('script,style,noscript,nav,aside,footer,form,iframe,svg,[hidden],[aria-hidden="true"]').forEach(function (element) {
                element.remove();
            });
            content.querySelectorAll('p,li,h1,h2,h3,h4,br,div').forEach(function (element) {
                element.appendChild(document.createTextNode("\n"));
            });
        }

        arguments.completionFunction({
            url: location.href,
            title: (readMeta("og:title") || document.title || "").slice(0, 500),
            image: readMeta("og:image"),
            text: content ? content.textContent.replace(/[\t ]+/g, " ").replace(/\n\s*\n/g, "\n").trim().slice(0, 40000) : "",
            jsonLD: blocks
        });
    }
};
