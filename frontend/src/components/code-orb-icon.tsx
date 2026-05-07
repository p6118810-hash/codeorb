"use client";

import { useId } from "react";

export function CodeOrbIcon({ className = "" }: { className?: string }) {
  const id = useId().replace(/:/g, "");
  const glowId = `code-orb-glow-${id}`;
  const coreId = `code-orb-core-${id}`;
  const shellId = `code-orb-shell-${id}`;

  return (
    <svg
      className={`code-orb-icon ${className}`}
      viewBox="0 0 64 64"
      role="img"
      aria-label="Code Orb"
      xmlns="http://www.w3.org/2000/svg"
    >
      <defs>
        <radialGradient id={shellId} cx="34%" cy="24%" r="78%">
          <stop offset="0%" stopColor="#3b4a40" />
          <stop offset="58%" stopColor="#101714" />
          <stop offset="100%" stopColor="#050706" />
        </radialGradient>
        <radialGradient id={coreId} cx="36%" cy="32%" r="74%">
          <stop offset="0%" stopColor="#f4ffd1" />
          <stop offset="42%" stopColor="#b9ff63" />
          <stop offset="100%" stopColor="#45d85f" />
        </radialGradient>
        <filter id={glowId} x="-50%" y="-50%" width="200%" height="200%">
          <feGaussianBlur stdDeviation="2.4" result="blur" />
          <feMerge>
            <feMergeNode in="blur" />
            <feMergeNode in="SourceGraphic" />
          </feMerge>
        </filter>
      </defs>

      <circle className="code-orb-shell" cx="32" cy="32" r="29" fill={`url(#${shellId})`} />
      <path
        className="code-orb-sheen"
        d="M16 27C19.8 15.8 31.8 10.2 43.4 14.1"
        fill="none"
        stroke="rgba(255,255,255,0.42)"
        strokeLinecap="round"
        strokeWidth="2.2"
      />
      <circle className="code-orb-orbit code-orb-orbit-one" cx="32" cy="32" r="18.5" />
      <circle className="code-orb-orbit code-orb-orbit-two" cx="32" cy="32" r="23.5" />
      <circle className="code-orb-core" cx="32" cy="32" r="8.8" fill={`url(#${coreId})`} filter={`url(#${glowId})`} />

      <g className="code-orb-planet-track code-orb-planet-track-one">
        <circle className="code-orb-planet" cx="50.5" cy="32" r="3.7" />
      </g>
      <g className="code-orb-planet-track code-orb-planet-track-two">
        <circle className="code-orb-planet code-orb-planet-small" cx="55.5" cy="32" r="2.6" />
      </g>
    </svg>
  );
}
