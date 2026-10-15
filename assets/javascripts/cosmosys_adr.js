// cosmosys_adr: in the edit form of a decided ADR, the subject and the
// description are shown read-only. The server refuses any change anyway;
// this only keeps the form from offering edits that would be refused.
(function () {
  'use strict';

  function lockDecidedAdrForm() {
    var fieldset = document.querySelector('fieldset.cosmosys-adr-fields[data-cosmosys-adr-locked="true"]');
    if (!fieldset) return;
    ['issue_subject', 'issue_description'].forEach(function (id) {
      var field = document.getElementById(id);
      if (field) field.readOnly = true;
    });
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', lockDecidedAdrForm);
  } else {
    lockDecidedAdrForm();
  }
  if (window.jQuery) window.jQuery(document).on('ajaxComplete', lockDecidedAdrForm);
})();
