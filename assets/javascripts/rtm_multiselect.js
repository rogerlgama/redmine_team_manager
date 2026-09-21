(function () {
  'use strict';

  function normalize(value) {
    return (value || '')
      .normalize('NFD')
      .replace(/[\u0300-\u036f]/g, '')
      .toLowerCase();
  }

  function enhance(select) {
    if (!select || select.dataset.rtmEnhanced === '1') return;
    select.dataset.rtmEnhanced = '1';

    var isMultiple = !!select.multiple;
    var wrapper = document.createElement('div');
    wrapper.className = 'rtm-multiselect' + (isMultiple ? ' is-multiple' : ' is-single');

    var control = document.createElement('button');
    control.type = 'button';
    control.className = 'rtm-multiselect-control';
    control.setAttribute('aria-haspopup', 'listbox');
    control.setAttribute('aria-expanded', 'false');

    var summary = document.createElement('span');
    summary.className = 'rtm-multiselect-summary';
    control.appendChild(summary);

    var arrow = document.createElement('span');
    arrow.className = 'rtm-multiselect-arrow';
    arrow.setAttribute('aria-hidden', 'true');
    arrow.textContent = '▾';
    control.appendChild(arrow);

    // Mantém o painel no <body> para que se sobreponha a tabelas/boxes do Redmine.
    var panel = document.createElement('div');
    panel.className = 'rtm-multiselect-panel';
    panel.hidden = true;

    var search = document.createElement('input');
    search.type = 'search';
    search.className = 'rtm-multiselect-search';
    search.placeholder = select.dataset.searchPlaceholder || select.dataset.placeholder || 'Pesquisar...';
    search.autocomplete = 'off';
    panel.appendChild(search);

    var list = document.createElement('div');
    list.className = 'rtm-multiselect-options';
    list.setAttribute('role', 'listbox');
    if (isMultiple) list.setAttribute('aria-multiselectable', 'true');
    panel.appendChild(list);

    var empty = document.createElement('div');
    empty.className = 'rtm-multiselect-empty';
    empty.textContent = select.dataset.noResults || 'Nenhum resultado encontrado.';
    empty.hidden = true;
    panel.appendChild(empty);

    Array.prototype.forEach.call(select.options, function (option) {
      // O option vazio de include_blank é representado pelo placeholder, não como item da lista.
      if (!isMultiple && option.value === '') return;

      var label = document.createElement('label');
      label.className = 'rtm-multiselect-option';
      label.dataset.search = normalize(option.text);
      label.setAttribute('role', 'option');
      label.setAttribute('aria-selected', option.selected ? 'true' : 'false');

      var chooser = document.createElement('input');
      chooser.type = isMultiple ? 'checkbox' : 'radio';
      chooser.checked = option.selected;
      chooser.value = option.value;
      if (!isMultiple) chooser.name = 'rtm-picker-' + (select.id || Math.random().toString(36).slice(2));

      var text = document.createElement('span');
      text.textContent = option.text;

      chooser.addEventListener('change', function () {
        if (isMultiple) {
          option.selected = chooser.checked;
          label.setAttribute('aria-selected', chooser.checked ? 'true' : 'false');
        } else if (chooser.checked) {
          Array.prototype.forEach.call(select.options, function (o) { o.selected = (o === option); });
          Array.prototype.forEach.call(list.querySelectorAll('.rtm-multiselect-option'), function (row) {
            var input = row.querySelector('input');
            row.setAttribute('aria-selected', input && input.checked ? 'true' : 'false');
          });
          closePanel();
          control.focus();
        }
        select.dispatchEvent(new Event('change', { bubbles: true }));
        updateSummary();
      });

      label.appendChild(chooser);
      label.appendChild(text);
      list.appendChild(label);
    });

    function selectedOptions() {
      return Array.prototype.filter.call(select.options, function (o) { return o.selected && o.value !== ''; });
    }

    function updateSummary() {
      var selected = selectedOptions();
      if (selected.length === 0) {
        summary.textContent = select.dataset.placeholder || 'Selecione...';
        summary.classList.add('placeholder');
      } else if (!isMultiple || selected.length <= 2) {
        summary.textContent = selected.map(function (o) { return o.text; }).join(', ');
        summary.classList.remove('placeholder');
      } else {
        summary.textContent = selected.slice(0, 2).map(function (o) { return o.text; }).join(', ') + ' +' + (selected.length - 2);
        summary.classList.remove('placeholder');
      }
      control.title = selected.map(function (o) { return o.text; }).join(', ');
    }

    function positionPanel() {
      if (panel.hidden) return;

      var rect = control.getBoundingClientRect();
      var viewportWidth = document.documentElement.clientWidth || window.innerWidth;
      var viewportHeight = document.documentElement.clientHeight || window.innerHeight;
      var gap = 4;
      var edge = 8;
      var desiredWidth = Math.max(rect.width, 420);
      var width = Math.min(desiredWidth, viewportWidth - (edge * 2));
      var left = Math.min(Math.max(rect.left, edge), viewportWidth - width - edge);

      panel.style.width = Math.round(width) + 'px';
      panel.style.left = Math.round(left) + 'px';

      var panelHeight = Math.min(panel.scrollHeight, 340);
      var spaceBelow = viewportHeight - rect.bottom - edge;
      var spaceAbove = rect.top - edge;

      if (spaceBelow >= Math.min(panelHeight, 180) || spaceBelow >= spaceAbove) {
        panel.style.top = Math.round(rect.bottom + gap) + 'px';
        panel.style.bottom = 'auto';
        panel.style.maxHeight = Math.max(140, Math.min(340, spaceBelow - gap)) + 'px';
      } else {
        panel.style.top = 'auto';
        panel.style.bottom = Math.round(viewportHeight - rect.top + gap) + 'px';
        panel.style.maxHeight = Math.max(140, Math.min(340, spaceAbove - gap)) + 'px';
      }
    }

    function openPanel() {
      panel.hidden = false;
      panel.classList.add('is-open');
      control.setAttribute('aria-expanded', 'true');
      search.value = '';
      filterOptions('');
      positionPanel();
      window.setTimeout(function () {
        positionPanel();
        search.focus();
      }, 0);
    }

    function closePanel() {
      panel.hidden = true;
      panel.classList.remove('is-open');
      control.setAttribute('aria-expanded', 'false');
    }

    function filterOptions(term) {
      var needle = normalize(term);
      var visible = 0;
      Array.prototype.forEach.call(list.children, function (label) {
        var show = label.dataset.search.indexOf(needle) !== -1;
        label.hidden = !show;
        if (show) visible += 1;
      });
      empty.hidden = visible !== 0;
    }

    control.addEventListener('click', function () {
      panel.hidden ? openPanel() : closePanel();
    });

    control.addEventListener('keydown', function (event) {
      if (event.key === 'ArrowDown' || event.key === 'Enter' || event.key === ' ') {
        event.preventDefault();
        openPanel();
      }
    });

    search.addEventListener('input', function () { filterOptions(search.value); });
    search.addEventListener('keydown', function (event) {
      if (event.key === 'Escape') {
        event.preventDefault();
        closePanel();
        control.focus();
      }
    });

    document.addEventListener('click', function (event) {
      if (!wrapper.contains(event.target) && !panel.contains(event.target)) closePanel();
    });

    window.addEventListener('resize', positionPanel);
    window.addEventListener('scroll', positionPanel, true);

    select.parentNode.insertBefore(wrapper, select);
    wrapper.appendChild(control);
    wrapper.appendChild(select);
    document.body.appendChild(panel);
    select.classList.add('rtm-searchable-select-native');
    updateSummary();
  }

  function initializeMemberDeleteConfirmation() {
    document.addEventListener('click', function (event) {
      var link = event.target.closest && event.target.closest('a[data-rtm-member-delete="1"]');
      if (!link || link.dataset.rtmConfirmed === '1') return;

      event.preventDefault();
      event.stopImmediatePropagation();

      var overlay = document.createElement('div');
      overlay.className = 'rtm-confirm-overlay';
      var dialog = document.createElement('div');
      dialog.className = 'rtm-confirm-dialog';
      dialog.setAttribute('role', 'dialog');
      dialog.setAttribute('aria-modal', 'true');

      var message = document.createElement('p');
      message.textContent = link.dataset.confirmMessage || 'Confirmar exclusão?';
      dialog.appendChild(message);

      var actions = document.createElement('div');
      actions.className = 'rtm-confirm-actions';
      var yes = document.createElement('button');
      yes.type = 'button';
      yes.textContent = link.dataset.yesLabel || 'Sim';
      var no = document.createElement('button');
      no.type = 'button';
      no.textContent = link.dataset.noLabel || 'Não';
      actions.appendChild(yes);
      actions.appendChild(no);
      dialog.appendChild(actions);
      overlay.appendChild(dialog);
      document.body.appendChild(overlay);

      function close() { if (overlay.parentNode) overlay.parentNode.removeChild(overlay); }
      no.addEventListener('click', close);
      overlay.addEventListener('click', function (e) { if (e.target === overlay) close(); });
      yes.addEventListener('click', function () {
        close();
        link.dataset.rtmConfirmed = '1';
        link.click();
      });
      no.focus();
    }, true);
  }

  function initialize() {
    initializeMemberDeleteConfirmation();
    Array.prototype.forEach.call(document.querySelectorAll('select.rtm-role-select[multiple], select.rtm-searchable-select'), enhance);
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initialize);
  } else {
    initialize();
  }
})();
