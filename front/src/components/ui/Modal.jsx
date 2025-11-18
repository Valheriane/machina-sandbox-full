// src/ui/Modal.jsx
import React, { useEffect, useRef } from "react";
import { createPortal } from "react-dom";

export default function Modal({
  open,
  onClose,
  title,
  children,
  size = "md",             // gardé pour compat, "md" = 640px (déjà en CSS)
  closeOnBackdrop = true,
  showClose = true,
  initialFocusRef,
  className,
}) {
  const dialogRef = useRef(null);
  const previousActive = useRef(null);
  const modalRoot = document.getElementById("modal-root") || document.body;

  useEffect(() => {
    if (open) {
      previousActive.current = document.activeElement;
      document.body.classList.add("no-scroll");

      const target =
        (initialFocusRef && initialFocusRef.current) ||
        dialogRef.current?.querySelector("[data-autofocus]") ||
        dialogRef.current;

      if (target && typeof target.focus === "function") target.focus();
    } else {
      document.body.classList.remove("no-scroll");
      if (previousActive.current && typeof previousActive.current.focus === "function") {
        previousActive.current.focus();
      }
    }
    return () => document.body.classList.remove("no-scroll");
  }, [open, initialFocusRef]);

  useEffect(() => {
    if (!open) return;
    const onKey = (e) => { if (e.key === "Escape") onClose?.(); };
    document.addEventListener("keydown", onKey);
    return () => document.removeEventListener("keydown", onKey);
  }, [open, onClose]);

  if (!open) return null;

  return createPortal(
    <div
      className="modal-overlay"
      aria-hidden={!open}
      onClick={closeOnBackdrop ? onClose : undefined}
    >
      <div className="modal-backdrop" />
      <div
        role="dialog"
        aria-modal="true"
        aria-label={typeof title === "string" ? title : undefined}
        ref={dialogRef}
        tabIndex={-1}
        className={`modal-panel ${className || ""}`}
        onClick={(e) => e.stopPropagation()}
      >
        {(title || showClose) && (
          <div className="modal-header">
            <div className="modal-title">{title}</div>
            {showClose && (
              <button className="modal-close" onClick={onClose} aria-label="Fermer la fenêtre">
                ✕
              </button>
            )}
          </div>
        )}
        <div className="modal-body">{children}</div>
      </div>
    </div>,
    modalRoot
  );
}
