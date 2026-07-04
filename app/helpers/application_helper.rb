module ApplicationHelper
  # A bare Tailwind `border-{color}` utility only sets the border's
  # *color*, not its width -- without the plain `border` utility too,
  # and with no `px`/`py`, an input falls back to the browser's native
  # (very thin) padding. Centralized here so every form gets the same
  # actually-visible, comfortably-sized field instead of that.
  def form_input_classes
    "mt-1 block w-full rounded-md border border-slate-300 px-3 py-2 text-sm shadow-sm " \
    "focus:border-slate-500 focus:outline-none focus:ring-1 focus:ring-slate-500"
  end

  def primary_button_classes
    "inline-block rounded-md bg-slate-900 px-4 py-2 text-sm font-medium text-white hover:bg-slate-700 cursor-pointer"
  end

  def danger_button_classes
    "inline-block rounded-md border border-red-200 bg-white px-3 py-1.5 text-sm font-medium text-red-600 hover:bg-red-50 cursor-pointer"
  end
end
