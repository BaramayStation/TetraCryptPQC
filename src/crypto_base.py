import numpy as np

class CryptoBase:
    def __init__(self, dimensions=4):
        self.dimensions = dimensions
        self._validate_dimensions()

    def _validate_dimensions(self):
        if not isinstance(self.dimensions, int) or self.dimensions < 1:
            raise ValueError('Dimensions must be a positive integer')
