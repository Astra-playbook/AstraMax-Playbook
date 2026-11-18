document.querySelectorAll("[data-copy]").forEach((button) => {
  button.addEventListener("click", async () => {
    const value = button.dataset.copy;
    let copied = false;

    try {
      await navigator.clipboard.writeText(value);
      copied = true;
    } catch {
      const field = document.createElement("textarea");
      field.value = value;
      field.setAttribute("readonly", "");
      field.style.position = "fixed";
      field.style.opacity = "0";
      document.body.appendChild(field);
      field.select();
      try {
        copied = document.execCommand("copy");
      } catch {
        copied = false;
      }
      field.remove();
    }

    if (!copied) {
      const target = button.closest(".hash-chip, .sha-box")?.querySelector("code");
      if (target) {
        const range = document.createRange();
        range.selectNodeContents(target);
        const selection = window.getSelection();
        selection.removeAllRanges();
        selection.addRange(range);
      }
    }

    const previous = button.textContent;
    button.textContent = copied ? "Copied" : "Select manually";
    button.classList.toggle("copied", copied);
    window.setTimeout(() => {
      button.textContent = previous;
      button.classList.remove("copied");
    }, 1800);
  });
});

const year = document.getElementById("year");
if (year) {
  year.textContent = new Date().getFullYear();
}
