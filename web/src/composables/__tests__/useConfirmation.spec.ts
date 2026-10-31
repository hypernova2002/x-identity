import { beforeEach, describe, expect, it, vi } from 'vitest'
import { useConfirm } from 'openvue/useconfirm'

import { useConfirmation } from '../useConfirmation'

vi.mock('openvue/useconfirm', () => ({ useConfirm: vi.fn<typeof useConfirm>() }))

interface Request {
  header: string
  rejectLabel: string
  acceptProps: { danger: boolean }
  accept: () => void
  reject: () => void
  onHide: () => void
}

describe('useConfirmation', () => {
  const require = vi.fn<(request: Request) => void>()

  beforeEach(() => {
    require.mockReset()
    vi.mocked(useConfirm).mockReturnValue({ require } as unknown as ReturnType<typeof useConfirm>)
  })

  const ask = (danger?: boolean) => useConfirmation()({ title: 'Delete project?', message: 'It goes for good.', confirmLabel: 'Delete', danger })
  const request = () => require.mock.calls[0]![0]

  it("shows the console's own dialog, with a cancel button by default", () => {
    void ask(true)

    expect(request()).toMatchObject({ header: 'Delete project?', rejectLabel: 'Cancel', acceptProps: { danger: true } })
  })

  it('resolves true on confirm, and ignores the dialog closing afterwards', async () => {
    const answer = ask()

    request().accept()
    request().onHide()

    await expect(answer).resolves.toBe(true)
  })

  it('resolves false when cancelled or dismissed', async () => {
    const cancelled = ask()
    request().reject()
    await expect(cancelled).resolves.toBe(false)

    require.mockReset()
    const dismissed = ask()
    request().onHide()
    await expect(dismissed).resolves.toBe(false)
  })
})
