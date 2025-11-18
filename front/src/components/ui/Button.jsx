import React from "react";
import clsx from "clsx";

/**
 * Button component
 * Props:
 * - variant: "primary" | "secondary" | "ghost" | "danger"
 * - size: "sm" | "md" | "lg"
 * - loading: boolean
 * - leftIcon / rightIcon: ReactNode
 */
export default function Button({
  as: Tag = "button",
  type = "button",
  variant = "primary",
  size = "md",
  loading = false,
  disabled,
  className,
  leftIcon,
  rightIcon,
  children,
  ...props
}) {
  const base =
    "inline-flex items-center justify-center gap-2 rounded-2xl font-medium transition-all outline-none focus-visible:ring-2 focus-visible:ring-offset-2 focus-visible:ring-indigo-500 disabled:opacity-60 disabled:cursor-not-allowed";

  const variants = {
    primary:
      "bg-indigo-600 text-white hover:bg-indigo-700 active:scale-[0.98] shadow-sm",
    secondary:
      "bg-white text-gray-900 border border-gray-200 hover:bg-gray-50 shadow-sm",
    ghost:
      "bg-transparent text-gray-700 hover:bg-gray-100 border border-transparent",
    danger:
      "bg-rose-600 text-white hover:bg-rose-700 active:scale-[0.98] shadow-sm",
  };

  const sizes = {
    sm: "text-sm px-3 py-1.5",
    md: "text-sm px-4 py-2",
    lg: "text-base px-5 py-3",
  };

  return (
    <Tag
      type={Tag === "button" ? type : undefined}
      className={clsx(base, variants[variant], sizes[size], className)}
      disabled={disabled || loading}
      {...props}
    >
      {leftIcon && <span className="shrink-0">{leftIcon}</span>}
      <span className="inline-flex items-center">
        {loading && (
          <svg
            className="mr-2 h-4 w-4 animate-spin"
            viewBox="0 0 24 24"
            fill="none"
          >
            <circle
              className="opacity-25"
              cx="12"
              cy="12"
              r="10"
              stroke="currentColor"
              strokeWidth="4"
            />
            <path
              className="opacity-75"
              fill="currentColor"
              d="M4 12a8 8 0 018-8v4a4 4 0 00-4 4H4z"
            />
          </svg>
        )}
        {children}
      </span>
      {rightIcon && <span className="shrink-0">{rightIcon}</span>}
    </Tag>
  );
}
