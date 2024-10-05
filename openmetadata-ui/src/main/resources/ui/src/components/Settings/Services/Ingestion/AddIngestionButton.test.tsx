/*
 *  Copyright 2024 Collate.
 *  Licensed under the Apache License, Version 2.0 (the "License");
 *  you may not use this file except in compliance with the License.
 *  You may obtain a copy of the License at
 *  http://www.apache.org/licenses/LICENSE-2.0
 *  Unless required by applicable law or agreed to in writing, software
 *  distributed under the License is distributed on an "AS IS" BASIS,
 *  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *  See the License for the specific language governing permissions and
 *  limitations under the License.
 */

import { act, render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import React from 'react';
import { MemoryRouter } from 'react-router-dom';
import { mockIngestionWorkFlow } from '../../../../mocks/Ingestion.mock';
import { mockAddIngestionButtonProps } from '../../../../mocks/IngestionListTable.mock';
import AddIngestionButton from './AddIngestionButton.component';

const mockPush = jest.fn();

jest.mock('../../../../hoc/LimitWrapper', () =>
  jest
    .fn()
    .mockImplementation(({ children }) => <div>LimitWrapper{children}</div>)
);

jest.mock('react-router-dom', () => ({
  useHistory: jest.fn().mockImplementation(() => ({
    push: mockPush,
  })),
}));

describe('AddIngestionButton', () => {
  it('should redirect to metadata ingestion page when no ingestion is present', async () => {
    await act(async () => {
      render(<AddIngestionButton {...mockAddIngestionButtonProps} />, {
        wrapper: MemoryRouter,
      });
    });
    const addIngestionButton = screen.getByTestId('add-new-ingestion-button');

    await act(async () => {
      userEvent.click(addIngestionButton);
    });

    expect(mockPush).toHaveBeenCalledWith(
      '/service/databaseServices/OpenMetadata/add-ingestion/metadata'
    );
  });

  it('should not redirect to metadata ingestion page when ingestion data is present', async () => {
    await act(async () => {
      render(
        <AddIngestionButton
          {...mockAddIngestionButtonProps}
          ingestionList={mockIngestionWorkFlow.data.data}
        />,
        {
          wrapper: MemoryRouter,
        }
      );
    });
    const addIngestionButton = screen.getByTestId('add-new-ingestion-button');

    await act(async () => {
      userEvent.click(addIngestionButton);
    });

    expect(mockPush).toHaveBeenCalledTimes(0);
  });
});
