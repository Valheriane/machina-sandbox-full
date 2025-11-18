// src/components/Hint.jsx
import { useId } from "react";

export default function Hint({
  text,
  size = "md",
  wide = false,
  ml,
  placement = "top", // "top" (par défaut), "left", "right"
  className = "",
}) {
  const tid = useId();
  return (
    <button
      type="button"
      className={`hint ${className}`}
      style={ml ? { marginLeft: ml } : undefined}
      data-size={size}
      data-placement={placement}
      aria-describedby={tid}
    >
      <span className="hint-dot">?</span>
      <span
        id={tid}
        className={`hint-bubble${wide ? " wide" : ""}`}
        role="tooltip"
      >
        {text}
      </span>
    </button>
  );
}
