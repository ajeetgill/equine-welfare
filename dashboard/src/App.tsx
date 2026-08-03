import { useEffect, useState } from "react";
import { Monitor, Moon, Sun } from "lucide-react";
import { getPocketBase } from "./lib/pocketbase";
import { Theme, useTheme } from "./lib/useTheme";
import Dashboard from "./components/Dashboard";
import Login from "./components/Login";
import logo from "./assets/logo-small.png";

const THEME_ORDER: Theme[] = ["light", "dark", "system"];

function ThemeToggle() {
  const { theme, setTheme } = useTheme();
  const next = THEME_ORDER[(THEME_ORDER.indexOf(theme) + 1) % THEME_ORDER.length];
  const Icon = theme === "light" ? Sun : theme === "dark" ? Moon : Monitor;
  return (
    <button
      onClick={() => setTheme(next)}
      title={`Theme: ${theme} (click for ${next})`}
      className="p-2 rounded-md hover:bg-muted"
    >
      <Icon className="w-4 h-4" />
    </button>
  );
}

export default function App() {
  const pb = getPocketBase();
  const [signedIn, setSignedIn] = useState(pb.authStore.isValid);
  const [email, setEmail] = useState<string | null>(
    (pb.authStore.record?.email as string | undefined) ?? null
  );

  useEffect(() => {
    return pb.authStore.onChange(() => {
      setSignedIn(pb.authStore.isValid);
      setEmail((pb.authStore.record?.email as string | undefined) ?? null);
    });
  }, [pb]);

  return (
    <main className="min-h-screen flex flex-col items-center">
      <div className="flex-1 w-full flex flex-col gap-20 items-center">
        <nav className="w-full flex justify-center border-b border-b-foreground/10 h-16">
          <div className="w-full max-w-5xl flex justify-between items-center p-3 px-5 text-sm">
            <span className="flex items-center text-lg font-black">
              <img
                src={logo}
                className="w-auto max-w-[35px]"
                alt="Horse C.O.P logo"
              />
              C.O.P
            </span>
            <div className="flex items-center gap-3">
              {signedIn && (
                <>
                  <span className="text-xs text-muted-foreground">{email}</span>
                  <button
                    onClick={() => pb.authStore.clear()}
                    className="border rounded-md py-1.5 px-3 text-xs hover:bg-muted"
                  >
                    Sign out
                  </button>
                </>
              )}
              <ThemeToggle />
            </div>
          </div>
        </nav>
        {signedIn ? <Dashboard email={email} /> : <Login />}
      </div>
    </main>
  );
}
