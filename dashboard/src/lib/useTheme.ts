import { useEffect, useState } from "react";

export type Theme = "light" | "dark" | "system";

function systemPrefersDark(): boolean {
  return window.matchMedia("(prefers-color-scheme: dark)").matches;
}

function apply(theme: Theme) {
  const dark = theme === "dark" || (theme === "system" && systemPrefersDark());
  document.documentElement.classList.toggle("dark", dark);
}

function storedTheme(): Theme {
  const value = localStorage.getItem("theme");
  return value === "light" || value === "dark" ? value : "system";
}

// Called once before React renders (main.tsx) so a dark-theme user doesn't
// get a white flash while the app mounts.
export function initTheme() {
  apply(storedTheme());
}

export function useTheme() {
  const [theme, setThemeState] = useState<Theme>(storedTheme);

  useEffect(() => {
    apply(theme);
    if (theme !== "system") return;
    const mq = window.matchMedia("(prefers-color-scheme: dark)");
    const onChange = () => apply("system");
    mq.addEventListener("change", onChange);
    return () => mq.removeEventListener("change", onChange);
  }, [theme]);

  const setTheme = (t: Theme) => {
    localStorage.setItem("theme", t);
    setThemeState(t);
  };

  return { theme, setTheme };
}
