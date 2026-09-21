(function () {
  'use strict';

  function isTechnicalTeamLabel(label) {
    if (!label) return false;
    var text = (label.textContent || '').replace(/\s+/g, ' ').trim();
    return text.indexOf('[TIME] ') !== -1 || text.indexOf('[TIME-ARQUIVADO] ') !== -1;
  }

  function filterNativeMemberSelector(root) {
    root = root || document;
    var container = root.querySelector ? root.querySelector('#principals_for_new_member') : null;
    if (!container && root.matches && root.matches('#principals_for_new_member')) container = root;
    if (!container) return;

    container.querySelectorAll('label').forEach(function (label) {
      if (isTechnicalTeamLabel(label)) {
        // Labels are the rendered selectable unit in Redmine's native dialog.
        // Remove the complete label so the checkbox cannot be used manually.
        label.remove();
      }
    });
  }

  function run() {
    filterNativeMemberSelector(document);
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', run);
  } else {
    run();
  }

  // The search box refreshes #principals_for_new_member through AJAX.
  // Observe those replacements and filter again after every response.
  var observer = new MutationObserver(function (mutations) {
    mutations.forEach(function (mutation) {
      mutation.addedNodes.forEach(function (node) {
        if (node.nodeType !== 1) return;
        if (node.matches && node.matches('#principals_for_new_member')) {
          filterNativeMemberSelector(node);
        } else if (node.querySelector && node.querySelector('#principals_for_new_member')) {
          filterNativeMemberSelector(node);
        } else if (node.closest && node.closest('#principals_for_new_member')) {
          filterNativeMemberSelector(node.closest('#principals_for_new_member'));
        }
      });
    });
  });

  function startObserver() {
    if (document.body) observer.observe(document.body, { childList: true, subtree: true });
  }

  if (document.body) startObserver();
  else document.addEventListener('DOMContentLoaded', startObserver);
})();
